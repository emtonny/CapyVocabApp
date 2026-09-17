param([string]$PostgresBin = 'C:\Program Files\PostgreSQL\18\bin')
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
foreach ($binary in @('initdb.exe', 'pg_ctl.exe', 'psql.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PostgresBin $binary))) { throw 'Installed native PostgreSQL tools are required; no installation performed.' }
}
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start(); $port = $listener.LocalEndpoint.Port; $listener.Stop()
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('capy-c2-postgres-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $testRoot
$dataRoot = Join-Path $testRoot 'data'
$startAttempted = $false
try {
    $output = (& (Join-Path $PostgresBin 'initdb.exe') -D $dataRoot -U capy_c2_test_admin -A trust --encoding=UTF8 --no-locale 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Disposable PostgreSQL initdb failed.' }
    $startAttempted = $true
    $startup = Start-Process -FilePath (Join-Path $PostgresBin 'pg_ctl.exe') -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $testRoot 'startup.stdout') -RedirectStandardError (Join-Path $testRoot 'startup.stderr') `
        -ArgumentList @('-D', ('"{0}"' -f $dataRoot), '-l', ('"{0}"' -f (Join-Path $testRoot 'server.log')), '-o', ('"-h 127.0.0.1 -p {0} -c wal_level=logical"' -f $port), '-w', '-t', '30', 'start')
    if (-not $startup.WaitForExit(40000)) { throw 'Disposable pg_ctl startup exceeded its deadline.' }
    if ($startup.ExitCode -ne 0) { throw 'Disposable PostgreSQL startup failed; existing local instances were not touched.' }
    $output = (& (Join-Path $PostgresBin 'psql.exe') -X -h 127.0.0.1 -p $port -U capy_c2_test_admin -d postgres -v ON_ERROR_STOP=1 `
        -f (Join-Path $repoRoot 'supabase\tests\chat_operational_bootstrap.sql') `
        -f (Join-Path $repoRoot 'supabase\migrations\20260915120000_add_operational_chat_security.sql') `
        -f (Join-Path $repoRoot 'supabase\tests\chat_operational_security.sql') 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) { throw "C2 native SQL tests failed (synthetic data only):`n$output" }
    $passes = [regex]::Matches($output, 'PASS:').Count
    if ($passes -ne 47) { throw 'Expected all 47 C2 SQL checks; refusing incomplete verification.' }
    [pscustomobject]@{status='VERIFIED'; sql_checks=$passes; engine='Native PostgreSQL isolated temporary cluster'; remote_writes=0} | ConvertTo-Json
}
finally {
    if ($startAttempted) {
        $null = & (Join-Path $PostgresBin 'pg_ctl.exe') -D $dataRoot status 2>&1
        if ($LASTEXITCODE -eq 0) {
            $null = & (Join-Path $PostgresBin 'pg_ctl.exe') -D $dataRoot -w -t 30 -m fast stop 2>&1
            if ($LASTEXITCODE -ne 0) { throw 'Disposable PostgreSQL stop failed; preserving files for diagnosis.' }
        }
        elseif ($LASTEXITCODE -ne 3) {
            throw 'Disposable PostgreSQL status is uncertain; preserving files instead of deleting a potentially active cluster.'
        }
    }
    $resolved = (Resolve-Path -LiteralPath $testRoot).Path
    $temporaryParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($temporaryParent, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolved) -notlike 'capy-c2-postgres-*') { throw 'Refusing cleanup outside allocated test directory.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
