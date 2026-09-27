#requires -Version 7.0
# Resumes Chat translation smoke without reading the Vilao credential again.
param(
    [string]$PostgresBin = 'C:\Program Files\PostgreSQL\18\bin',
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
$stagingRef = 'nxteaznowkfennxpqjmt'
$stagingName = "emtonny's Project"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$psql = Join-Path $PostgresBin 'psql.exe'
$previousEnvironment = @{}
$triggerSecret = $null

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

if ($SelfTest) {
    $sample = @'
export PGHOST="db.nxteaznowkfennxpqjmt.test"
export PGPORT="5432"
export PGUSER="temporary_user"
export PGPASSWORD="synthetic_password"
export PGDATABASE="postgres"
'@
    $parsed = Get-PostgresEnvironment $sample
    if ($parsed.Count -ne 5 -or
        $parsed.PGHOST -ne 'db.nxteaznowkfennxpqjmt.test') {
        throw 'C4G resume self-test failed.'
    }
    Write-Host 'C4G resume self-test passed: bounded credential parser.'
    exit 0
}

if (-not (Test-Path -LiteralPath $psql)) {
    throw 'Installed PostgreSQL psql is required; no installation performed.'
}

Push-Location $repoRoot
try {
    $projectsText = (& npx.cmd supabase projects list --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to verify exact Staging.' }
    $project = @(ConvertFrom-Json $projectsText | Where-Object {
        $_.ref -eq $stagingRef
    })
    if ($project.Count -ne 1 -or $project[0].name -cne $stagingName -or
        $project[0].status -ne 'ACTIVE_HEALTHY' -or -not $project[0].linked) {
        throw 'Refusing smoke resume: linked project is not exact healthy Staging.'
    }

    $dryRun = (& npx.cmd supabase db push --linked --dry-run | Out-String)
    if ($LASTEXITCODE -ne 0 -or $dryRun -notmatch '"upToDate":true') {
        throw 'Refusing smoke resume: exact Staging migrations are not up to date.'
    }

    $dumpScript = (& npx.cmd supabase db dump --project-ref $stagingRef `
        --dry-run | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to obtain the temporary Staging Vault connection.'
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

    $vaultSql = @'
SET ROLE postgres;
SELECT json_build_object(
    'worker_url_entries', count(*) FILTER (
        WHERE name = 'chat_translation_worker_url'
    ),
    'trigger_entries', count(*) FILTER (
        WHERE name = 'chat_translation_trigger_secret'
    ),
    'remote_training_table', to_regclass('public.training_examples')
)
FROM vault.secrets
WHERE name IN (
    'chat_translation_worker_url',
    'chat_translation_trigger_secret'
);
SELECT decrypted_secret
FROM vault.decrypted_secrets
WHERE name = 'chat_translation_trigger_secret';
'@
    $vaultLines = @($vaultSql | & $psql -X -q -v ON_ERROR_STOP=1 -At -f - `
        2>$null)
    if ($LASTEXITCODE -ne 0 -or $vaultLines.Count -ne 2 -or
        $vaultLines[0] -notmatch '"worker_url_entries"\s*:\s*1' -or
        $vaultLines[0] -notmatch '"trigger_entries"\s*:\s*1' -or
        $vaultLines[0] -notmatch '"remote_training_table"\s*:\s*null') {
        throw 'Staging Vault verification failed; values were not logged.'
    }
    $triggerSecret = ([string]$vaultLines[1]).Trim()
    if ($triggerSecret -cnotmatch '^[A-Za-z0-9_-]{32,256}$') {
        throw 'Stored Staging trigger secret has an invalid shape.'
    }
    [Environment]::SetEnvironmentVariable(
        'CHAT_TRANSLATION_TRIGGER_SECRET', $triggerSecret, 'Process'
    )

    $smokeOutput = (& (Join-Path $PSScriptRoot `
        'run_staging_chat_translation_e2e.ps1') 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -or
        $smokeOutput -notmatch '"status"\s*:\s*"VERIFIED"') {
        throw "C4G live smoke failed; fixture cleanup was attempted by the runner.`n$smokeOutput"
    }

    [pscustomobject]@{
        status = 'VERIFIED'
        project_ref = $stagingRef
        vault_entries = 2
        live_smoke = 'VERIFIED'
        provider_key_reread = $false
    } | ConvertTo-Json
}
finally {
    foreach ($name in $previousEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable(
            $name, $previousEnvironment[$name], 'Process'
        )
    }
    [Environment]::SetEnvironmentVariable(
        'CHAT_TRANSLATION_TRIGGER_SECRET', $null, 'Process'
    )
    $triggerSecret = $null
    $vaultLines = $null
    $dumpScript = $null
    $postgresEnvironment = $null
    Pop-Location
}
