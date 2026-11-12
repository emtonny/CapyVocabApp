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

$testRoot = Join-Path ([IO.Path]::GetTempPath()) (
    'capy-friend-f1-postgres-' + [guid]::NewGuid()
)
$null = New-Item -ItemType Directory -Path $testRoot
$dataRoot = Join-Path $testRoot 'data'
$startAttempted = $false

function Invoke-F1Psql {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Files
    )

    $arguments = @(
        '-X',
        '-h', '127.0.0.1',
        '-p', $port,
        '-U', 'capy_friend_f1_admin',
        '-d', 'postgres',
        '-v', 'ON_ERROR_STOP=1'
    )
    foreach ($file in $Files) {
        $arguments += @('-f', $file)
    }

    $ErrorActionPreference = 'Continue'
    $output = (& (Join-Path $PostgresBin 'psql.exe') @arguments 2>&1 | Out-String)
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($exitCode -ne 0) {
        throw "F1 native SQL tests failed (synthetic data only):`n$output"
    }
    return $output
}

try {
    $output = (& (Join-Path $PostgresBin 'initdb.exe') `
        -D $dataRoot `
        -U capy_friend_f1_admin `
        -A trust `
        --encoding=UTF8 `
        --no-locale 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw 'Disposable PostgreSQL initdb failed.'
    }

    $startAttempted = $true
    $startup = Start-Process `
        -FilePath (Join-Path $PostgresBin 'pg_ctl.exe') `
        -WindowStyle Hidden `
        -PassThru `
        -RedirectStandardOutput (Join-Path $testRoot 'startup.stdout') `
        -RedirectStandardError (Join-Path $testRoot 'startup.stderr') `
        -ArgumentList @(
            '-D', ('"{0}"' -f $dataRoot),
            '-l', ('"{0}"' -f (Join-Path $testRoot 'server.log')),
            '-o', ('"-h 127.0.0.1 -p {0} -c wal_level=logical"' -f $port),
            '-w', '-t', '30', 'start'
        )
    if (-not $startup.WaitForExit(40000)) {
        throw 'Disposable PostgreSQL startup exceeded its deadline.'
    }
    if ($startup.ExitCode -ne 0) {
        $null = & (Join-Path $PostgresBin 'pg_ctl.exe') -D $dataRoot status 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw 'Disposable PostgreSQL startup failed; existing local instances were not touched.'
        }
    }

    $mainOutput = Invoke-F1Psql -Files @(
        (Join-Path $repoRoot 'supabase\tests\friend_f1_bootstrap.sql'),
        (Join-Path $repoRoot 'supabase\migrations\20260915120000_add_operational_chat_security.sql'),
        (Join-Path $repoRoot 'supabase\tests\friend_f1_pre_migration.sql'),
        (Join-Path $repoRoot 'supabase\migrations\20260922120000_add_friend_management_contract.sql'),
        (Join-Path $repoRoot 'supabase\migrations\20260923120000_accept_supabase_auth_phone_format.sql'),
        (Join-Path $repoRoot 'supabase\tests\friend_f1_security.sql')
    )

    $psql = Join-Path $PostgresBin 'psql.exe'
    $concurrentFiles = @(
        (Join-Path $repoRoot 'supabase\tests\friend_f1_concurrent_send_a.sql'),
        (Join-Path $repoRoot 'supabase\tests\friend_f1_concurrent_send_b.sql')
    )
    $processes = @()
    for ($index = 0; $index -lt $concurrentFiles.Count; $index++) {
        $stdoutPath = Join-Path $testRoot ("concurrent-{0}.stdout" -f $index)
        $stderrPath = Join-Path $testRoot ("concurrent-{0}.stderr" -f $index)
        $concurrentProcess = Start-Process `
            -FilePath $psql `
            -WindowStyle Hidden `
            -PassThru `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath `
            -ArgumentList @(
                '-X',
                '-h', '127.0.0.1',
                '-p', $port,
                '-U', 'capy_friend_f1_admin',
                '-d', 'postgres',
                '-v', 'ON_ERROR_STOP=1',
                '-f', ('"{0}"' -f $concurrentFiles[$index])
            )
        # PowerShell 5.1 only retains ExitCode reliably if the handle is opened
        # before the short-lived process exits.
        $null = $concurrentProcess.Handle
        $processes += $concurrentProcess
    }

    foreach ($process in $processes) {
        if (-not $process.WaitForExit(30000)) {
            Stop-Process -Id $process.Id -Force
            throw 'Concurrent friend request verification exceeded its deadline.'
        }
        # Complete redirected stream draining before reading ExitCode on Windows.
        $process.WaitForExit()
        $process.Refresh()
        if ($process.ExitCode -ne 0) {
            $processIndex = $processes.IndexOf($process)
            $stderrPath = Join-Path $testRoot ("concurrent-{0}.stderr" -f $processIndex)
            $stdoutPath = Join-Path $testRoot ("concurrent-{0}.stdout" -f $processIndex)
            $stderr = if (Test-Path -LiteralPath $stderrPath) {
                Get-Content -Raw $stderrPath
            }
            else { '' }
            $stdout = if (Test-Path -LiteralPath $stdoutPath) {
                Get-Content -Raw $stdoutPath
            }
            else { '' }
            throw "Concurrent friend request failed (exit $($process.ExitCode)):`nSTDOUT:`n$stdout`nSTDERR:`n$stderr"
        }
    }

    $concurrencyOutput = Invoke-F1Psql -Files @(
        (Join-Path $repoRoot 'supabase\tests\friend_f1_concurrency_verify.sql')
    )
    $passes = [regex]::Matches($mainOutput + $concurrencyOutput, 'PASS:').Count
    if ($passes -ne 68) {
        throw "Expected all 68 F1 SQL checks; observed $passes. Refusing incomplete verification."
    }

    [pscustomobject]@{
        status = 'VERIFIED'
        sql_checks = $passes
        concurrency_clients = 2
        engine = 'Native PostgreSQL isolated temporary cluster'
        remote_writes = 0
    } | ConvertTo-Json
}
finally {
    if ($startAttempted) {
        $null = & (Join-Path $PostgresBin 'pg_ctl.exe') -D $dataRoot status 2>&1
        if ($LASTEXITCODE -eq 0) {
            $null = & (Join-Path $PostgresBin 'pg_ctl.exe') `
                -D $dataRoot -w -t 30 -m fast stop 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw 'Disposable PostgreSQL stop failed; preserving files for diagnosis.'
            }
        }
        elseif ($LASTEXITCODE -ne 3) {
            throw 'Disposable PostgreSQL status is uncertain; preserving files instead of deleting a potentially active cluster.'
        }
    }

    $resolved = (Resolve-Path -LiteralPath $testRoot).Path
    $temporaryParent = [IO.Path]::GetFullPath(
        [IO.Path]::GetTempPath()
    ).TrimEnd('\') + '\'
    if (-not $resolved.StartsWith(
            $temporaryParent,
            [StringComparison]::OrdinalIgnoreCase
        ) -or [IO.Path]::GetFileName($resolved) -notlike 'capy-friend-f1-postgres-*') {
        throw 'Refusing cleanup outside allocated F1 test directory.'
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
