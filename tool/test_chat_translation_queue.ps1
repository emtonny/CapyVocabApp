param([string]$PostgresBin = 'C:\Program Files\PostgreSQL\18\bin')
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
foreach ($binary in @('initdb.exe', 'pg_ctl.exe', 'psql.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PostgresBin $binary))) {
        throw 'Installed native PostgreSQL tools are required; no installation performed.'
    }
}

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = $listener.LocalEndpoint.Port
$listener.Stop()
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('capy-c4b-postgres-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $testRoot
$dataRoot = Join-Path $testRoot 'data'
$startAttempted = $false

try {
    $output = (& (Join-Path $PostgresBin 'initdb.exe') -D $dataRoot `
        -U capy_c4b_test_admin -A trust --encoding=UTF8 --no-locale 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Disposable PostgreSQL initdb failed.' }

    $startAttempted = $true
    $startup = Start-Process -FilePath (Join-Path $PostgresBin 'pg_ctl.exe') `
        -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $testRoot 'startup.stdout') `
        -RedirectStandardError (Join-Path $testRoot 'startup.stderr') `
        -ArgumentList @(
            '-D', ('"{0}"' -f $dataRoot),
            '-l', ('"{0}"' -f (Join-Path $testRoot 'server.log')),
            '-o', ('"-h 127.0.0.1 -p {0} -c wal_level=logical"' -f $port),
            '-w', '-t', '30', 'start'
        )
    if (-not $startup.WaitForExit(40000)) {
        throw 'Disposable pg_ctl startup exceeded its deadline.'
    }
    if ($startup.ExitCode -ne 0) {
        $statusOutput = (& (Join-Path $PostgresBin 'pg_ctl.exe') -D $dataRoot status `
            2>&1 | Out-String)
        if ($LASTEXITCODE -ne 0) {
            $startupError = Get-Content -LiteralPath (Join-Path $testRoot 'startup.stderr') `
                -Raw -ErrorAction SilentlyContinue
            $serverError = Get-Content -LiteralPath (Join-Path $testRoot 'server.log') `
                -Raw -ErrorAction SilentlyContinue
            throw "Disposable PostgreSQL startup failed; existing local instances were not touched.`n$statusOutput`n$startupError`n$serverError"
        }
    }

    $connection = 'host=127.0.0.1 port={0} dbname=postgres user=capy_c4b_test_admin' -f $port
    # Windows PowerShell promotes PostgreSQL NOTICE lines on stderr to error
    # records. Capture them and trust psql's exit code instead.
    $ErrorActionPreference = 'Continue'
    $output = (& (Join-Path $PostgresBin 'psql.exe') -X `
        -h 127.0.0.1 -p $port -U capy_c4b_test_admin -d postgres `
        -v ON_ERROR_STOP=1 -v ('test_connstr={0}' -f $connection) `
        -f (Join-Path $repoRoot 'supabase\tests\chat_operational_bootstrap.sql') `
        -f (Join-Path $repoRoot 'supabase\migrations\20260915120000_add_operational_chat_security.sql') `
        -f (Join-Path $repoRoot 'supabase\tests\chat_translation_queue_pre_migration.sql') `
        -f (Join-Path $repoRoot 'supabase\migrations\20260918120000_add_chat_translation_queue_claim.sql') `
        -f (Join-Path $repoRoot 'supabase\tests\chat_translation_wakeup_bootstrap.sql') `
        -f (Join-Path $repoRoot 'supabase\migrations\20260918130000_add_chat_translation_worker_wakeup.sql') `
        -f (Join-Path $repoRoot 'supabase\migrations\20260921120000_add_vilao_chat_translation_v2.sql') `
        -f (Join-Path $repoRoot 'supabase\tests\chat_translation_queue_security.sql') `
        -f (Join-Path $repoRoot 'supabase\tests\chat_translation_wakeup_security.sql') `
        -f (Join-Path $repoRoot 'supabase\migrations\20261021110000_add_gemini_chat_translation_v3.sql') `
        -f (Join-Path $repoRoot 'supabase\tests\chat_translation_v3_security.sql') `
        2>&1 | Out-String)
    $psqlExitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($psqlExitCode -ne 0) {
        throw "C4B native SQL tests failed (synthetic data only):`n$output"
    }

    $passes = [regex]::Matches($output, 'PASS:').Count
    if ($passes -ne 64) {
        throw "Expected all 64 C4B/C4G SQL checks; observed $passes."
    }
    [pscustomobject]@{
        status = 'VERIFIED'
        sql_checks = $passes
        concurrency = 'two real PostgreSQL connections with SKIP LOCKED'
        wakeup = 'transactional queue trigger plus one-minute recovery schedule'
        engine = 'Native PostgreSQL isolated temporary cluster'
        remote_writes = 0
    } | ConvertTo-Json
}
finally {
    if ($startAttempted) {
        $null = & (Join-Path $PostgresBin 'pg_ctl.exe') -D $dataRoot status 2>&1
        if ($LASTEXITCODE -eq 0) {
            $null = & (Join-Path $PostgresBin 'pg_ctl.exe') -D $dataRoot `
                -w -t 30 -m fast stop 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw 'Disposable PostgreSQL stop failed; preserving files for diagnosis.'
            }
        }
        elseif ($LASTEXITCODE -ne 3) {
            throw 'Disposable PostgreSQL status is uncertain; preserving files instead of deleting a potentially active cluster.'
        }
    }

    $resolved = (Resolve-Path -LiteralPath $testRoot).Path
    $temporaryParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($temporaryParent, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolved) -notlike 'capy-c4b-postgres-*') {
        throw 'Refusing cleanup outside allocated C4B test directory.'
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
