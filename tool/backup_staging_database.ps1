param(
    [string]$PostgresBin = 'C:\Program Files\PostgreSQL\18\bin',
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
$stagingRef = 'nxteaznowkfennxpqjmt'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

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

function Get-Sha256([byte[]]$Bytes) {
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [BitConverter]::ToString($hasher.ComputeHash($Bytes)).Replace('-', '').ToLowerInvariant()
    }
    finally { $hasher.Dispose() }
}

if ($SelfTest) {
    $sample = @'
export PGHOST="host.test"
export PGPORT="5432"
export PGUSER="temporary_user"
export PGPASSWORD="synthetic_password"
export PGDATABASE="postgres"
'@
    $parsed = Get-PostgresEnvironment $sample
    if ($parsed.PGHOST -ne 'host.test' -or $parsed.Count -ne 5) {
        throw 'Credential parser round-trip failed.'
    }
    foreach ($invalid in @(
        $sample.Replace('"synthetic_password"', '"$(unsafe)"'),
        $sample.Replace('export PGDATABASE="postgres"', ''),
        ($sample + "`nexport PGHOST=`"duplicate`"")
    )) {
        $rejected = $false
        try { $null = Get-PostgresEnvironment $invalid }
        catch { $rejected = $true }
        if (-not $rejected) { throw 'Unsafe/incomplete credentials were accepted.' }
    }
    Write-Host 'Backup self-test passed: round-trip, shell expansion, missing and duplicate variables.'
    exit 0
}

$dumpCommand = Join-Path $PostgresBin 'pg_dump.exe'
$restoreCommand = Join-Path $PostgresBin 'pg_restore.exe'
if (-not (Test-Path -LiteralPath $dumpCommand) -or
    -not (Test-Path -LiteralPath $restoreCommand)) {
    throw 'Installed PostgreSQL dump/restore tools are required; nothing was installed.'
}

$previousEnvironment = @{}
$temporaryRoot = $null
$dumpScript = $null
$postgresEnvironment = $null
Push-Location $repoRoot
try {
    $projectsOutput = (& npx.cmd supabase projects list --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to verify Staging target.' }
    $projects = ConvertFrom-Json $projectsOutput
    $staging = @($projects | Where-Object { $_.ref -eq $stagingRef })
    if ($staging.Count -ne 1 -or $staging[0].name -ne "emtonny's Project" -or
        $staging[0].status -ne 'ACTIVE_HEALTHY' -or -not $staging[0].linked) {
        throw 'Refusing backup: linked target is not the expected healthy Staging project.'
    }

    $migrationHistory = (& npx.cmd supabase migration list --project-ref $stagingRef | Out-String)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($migrationHistory)) {
        throw 'Unable to capture read-only Staging migration history.'
    }

    # Capture, never print or execute the shell script containing temporary credentials.
    $dumpScript = (& npx.cmd supabase db dump --project-ref $stagingRef --dry-run | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to obtain Staging backup connection.' }
    if ($dumpScript -notmatch '--role(?:=|\s+)["'']?postgres') {
        throw 'Expected CLI-authorized postgres dump role was not returned.'
    }
    $postgresEnvironment = Get-PostgresEnvironment $dumpScript
    foreach ($name in $postgresEnvironment.Keys) {
        $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        [Environment]::SetEnvironmentVariable($name, $postgresEnvironment[$name], 'Process')
    }
    $previousEnvironment.PGSSLMODE = [Environment]::GetEnvironmentVariable('PGSSLMODE', 'Process')
    [Environment]::SetEnvironmentVariable('PGSSLMODE', 'require', 'Process')

    $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('capy-staging-backup-' + [guid]::NewGuid())
    $null = New-Item -ItemType Directory -Path $temporaryRoot
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $acl = [Security.AccessControl.DirectorySecurity]::new()
    $acl.SetOwner($sid)
    $acl.SetAccessRuleProtection($true, $false)
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
        $sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
    ))
    Set-Acl -LiteralPath $temporaryRoot -AclObject $acl

    $dumpPath = Join-Path $temporaryRoot 'staging.dump'
    $nativeOutput = (& $dumpCommand --format=custom --no-owner --role=postgres `
        --schema=public --schema=private `
        --file=$dumpPath 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
        $category = switch -Regex ($nativeOutput) {
            'permission denied for (table|schema|relation) ([a-zA-Z0-9_]+)' { "permission denied for $($Matches[1]) $($Matches[2])"; break }
            'password authentication failed' { 'temporary-login authentication failed'; break }
            'could not translate host name' { 'database DNS lookup failed'; break }
            'connection.*timed out|timeout expired' { 'database connection timeout'; break }
            'server version.*pg_dump version' { 'PostgreSQL version mismatch'; break }
            default { 'unclassified native error (credentials were not logged)' }
        }
        throw "Native Staging pg_dump failed: $category; no apply is permitted."
    }
    $contents = (& $restoreCommand --list $dumpPath 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -or $contents -notmatch 'TABLE DATA') {
        throw 'Staging archive cannot be read by pg_restore.'
    }

    Add-Type -AssemblyName System.Security
    $plainBytes = [IO.File]::ReadAllBytes($dumpPath)
    $cipherBytes = [Security.Cryptography.ProtectedData]::Protect(
        $plainBytes, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    $roundTrip = [Security.Cryptography.ProtectedData]::Unprotect(
        $cipherBytes, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    $plainHash = Get-Sha256 $plainBytes
    if ((Get-Sha256 $roundTrip) -ne $plainHash) { throw 'DPAPI verification failed.' }

    $backupRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'CapyVocabApp\staging_backups'
    $backupDirectory = Join-Path $backupRoot ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $null = New-Item -ItemType Directory -Path $backupDirectory -Force
    $encryptedPath = Join-Path $backupDirectory 'staging.dump.dpapi'
    [IO.File]::WriteAllBytes($encryptedPath, $cipherBytes)
    $persisted = [IO.File]::ReadAllBytes($encryptedPath)
    if ((Get-Sha256 $persisted) -ne (Get-Sha256 $cipherBytes)) {
        throw 'Persisted encrypted backup verification failed.'
    }
    $historyBytes = [Text.Encoding]::UTF8.GetBytes($migrationHistory)
    $historyCipher = [Security.Cryptography.ProtectedData]::Protect(
        $historyBytes, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    $historyRoundTrip = [Security.Cryptography.ProtectedData]::Unprotect(
        $historyCipher, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    $historyHash = Get-Sha256 $historyBytes
    if ((Get-Sha256 $historyRoundTrip) -ne $historyHash) {
        throw 'Migration history encryption verification failed.'
    }
    $historyPath = Join-Path $backupDirectory 'migration-history.txt.dpapi'
    [IO.File]::WriteAllBytes($historyPath, $historyCipher)
    if ((Get-Sha256 ([IO.File]::ReadAllBytes($historyPath))) -ne (Get-Sha256 $historyCipher)) {
        throw 'Persisted migration history verification failed.'
    }
    $manifest = [ordered]@{
        status = 'VERIFIED'
        project_ref = $stagingRef
        created_at = [DateTime]::UtcNow.ToString('o')
        schemas = @('public', 'private')
        migration_history = 'Separate encrypted CLI migration list; no additional DB grants'
        migration_history_sha256 = $historyHash
        excluded = @('auth', 'storage', 'Storage object bytes')
        format = 'PostgreSQL custom archive'
        encryption = 'Windows DPAPI CurrentUser; restore requires the same Windows profile'
        plaintext_sha256 = $plainHash
        encrypted_sha256 = Get-Sha256 $cipherBytes
        archive_bytes = $plainBytes.Length
        pg_restore_list_verified = $true
        dpapi_round_trip_verified = $true
    }
    [IO.File]::WriteAllText(
        (Join-Path $backupDirectory 'manifest.json'),
        ($manifest | ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false)
    )
    [pscustomobject]@{status='VERIFIED'; project_ref=$stagingRef; backup_directory=$backupDirectory; archive_bytes=$plainBytes.Length} | ConvertTo-Json
}
finally {
    foreach ($name in $previousEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process')
    }
    $dumpScript = $null
    $postgresEnvironment = $null
    $nativeOutput = $null
    $migrationHistory = $null
    foreach ($bytes in @($plainBytes, $roundTrip, $historyBytes, $historyRoundTrip)) {
        if ($null -ne $bytes) { [Array]::Clear($bytes, 0, $bytes.Length) }
    }
    if ($temporaryRoot -and (Test-Path -LiteralPath $temporaryRoot)) {
        $resolved = (Resolve-Path -LiteralPath $temporaryRoot).Path
        $expectedParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        if (-not $resolved.StartsWith($expectedParent, [StringComparison]::OrdinalIgnoreCase) -or
            [IO.Path]::GetFileName($resolved) -notlike 'capy-staging-backup-*') {
            throw 'Refusing plaintext cleanup outside the allocated temporary directory.'
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    Pop-Location
}
