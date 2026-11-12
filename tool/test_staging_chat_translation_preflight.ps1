param([string]$PostgresBin = 'C:\Program Files\PostgreSQL\18\bin')

$ErrorActionPreference = 'Stop'
$stagingRef = 'nxteaznowkfennxpqjmt'
$psql = Join-Path $PostgresBin 'psql.exe'
if (-not (Test-Path -LiteralPath $psql)) {
    throw 'Installed PostgreSQL psql is required; no installation performed.'
}

function Get-PostgresEnvironment([string]$Script) {
    $required = @('PGHOST', 'PGPORT', 'PGUSER', 'PGPASSWORD', 'PGDATABASE')
    $result = @{}
    foreach ($match in [regex]::Matches(
        $Script, '(?m)^\s*(?:export\s+)?(PG[A-Z]+)=(.*)$'
    )) {
        $name = $match.Groups[1].Value
        if ($name -notin $required) { continue }
        $quoted = $match.Groups[2].Value.Trim()
        if ($result.ContainsKey($name) -or
            $quoted -notmatch '^"([^"\\$`]+)"$') {
            throw 'Unsupported PostgreSQL credential quoting; refusing shell evaluation.'
        }
        $result[$name] = $Matches[1]
    }
    if ($result.Count -ne $required.Count) {
        throw 'Incomplete PostgreSQL environment in CLI dry-run.'
    }
    return $result
}

$previousEnvironment = @{}
$dumpScript = $null
$postgresEnvironment = $null
try {
    $projectsText = (& npx.cmd supabase projects list --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to verify Staging target.' }
    $projects = ConvertFrom-Json $projectsText
    $staging = @($projects | Where-Object { $_.ref -eq $stagingRef })
    if ($staging.Count -ne 1 -or $staging[0].name -ne "emtonny's Project" -or
        $staging[0].status -ne 'ACTIVE_HEALTHY' -or -not $staging[0].linked) {
        throw 'Refusing preflight: linked target is not exact healthy Staging.'
    }

    # Obtain a temporary CLI-authorized connection without printing or evaluating
    # the returned shell script.
    $dumpScript = (& npx.cmd supabase db dump --project-ref $stagingRef --dry-run |
        Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to obtain a read-only Staging preflight connection.'
    }
    $postgresEnvironment = Get-PostgresEnvironment $dumpScript
    if ($postgresEnvironment.PGHOST -notlike "*$stagingRef*") {
        throw 'Temporary database host does not belong to exact Staging.'
    }
    foreach ($name in $postgresEnvironment.Keys) {
        $previousEnvironment[$name] =
            [Environment]::GetEnvironmentVariable($name, 'Process')
        [Environment]::SetEnvironmentVariable(
            $name, $postgresEnvironment[$name], 'Process'
        )
    }
    $previousEnvironment.PGSSLMODE =
        [Environment]::GetEnvironmentVariable('PGSSLMODE', 'Process')
    [Environment]::SetEnvironmentVariable('PGSSLMODE', 'require', 'Process')

    $query = @'
SET ROLE postgres;
SELECT json_build_object(
    'pg_net', EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'pg_net'
    ),
    'pg_cron', EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
    ),
    'supabase_vault', EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'supabase_vault'
    ),
    'net_http_post', to_regprocedure(
        'net.http_post(text,jsonb,jsonb,jsonb,integer)'
    ) IS NOT NULL,
    'cron_schedule', to_regprocedure(
        'cron.schedule(text,text,text)'
    ) IS NOT NULL,
    'cron_unschedule', to_regprocedure(
        'cron.unschedule(bigint)'
    ) IS NOT NULL,
    'vault_secrets', to_regclass('vault.secrets') IS NOT NULL,
    'vault_decrypted_secrets',
        to_regclass('vault.decrypted_secrets') IS NOT NULL
);
'@
    $queryOutput = (& $psql -X -q -v ON_ERROR_STOP=1 -At -c $query 2>&1 |
        Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        $category = switch -Regex ($queryOutput) {
            'password authentication failed' { 'temporary-login authentication failed'; break }
            'could not translate host name' { 'database DNS lookup failed'; break }
            'connection.*timed out|timeout expired' { 'database connection timeout'; break }
            'syntax error' { 'preflight SQL syntax error'; break }
            'permission denied' { 'preflight role permission denied'; break }
            'does not exist' { 'required database object does not exist'; break }
            default { 'unclassified psql error' }
        }
        throw "Read-only Staging extension query failed: $category; credentials were not logged."
    }
    $jsonText = $queryOutput
    $checks = ConvertFrom-Json $jsonText
    $missing = @(
        $checks.PSObject.Properties |
        Where-Object { $_.Value -ne $true } |
        ForEach-Object { $_.Name }
    )
    $pgNetOnlyMissing = @($missing | Where-Object {
        $_ -notin @('pg_net', 'net_http_post')
    }).Count -eq 0 -and $missing.Count -eq 2
    [pscustomobject]@{
        status = if ($missing.Count -eq 0) {
            'VERIFIED'
        }
        elseif ($pgNetOnlyMissing) {
            'PG_NET_ENABLE_MIGRATION_REQUIRED'
        }
        else {
            'BLOCKED'
        }
        project_ref = $stagingRef
        required_capabilities = $checks
        missing = $missing
        remote_writes = 0
    } | ConvertTo-Json -Depth 4
    if ($missing.Count -ne 0 -and -not $pgNetOnlyMissing) {
        throw ('Staging is missing required capabilities: ' +
            ($missing -join ', '))
    }
}
finally {
    foreach ($name in $previousEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable(
            $name, $previousEnvironment[$name], 'Process'
        )
    }
    $dumpScript = $null
    $postgresEnvironment = $null
}
