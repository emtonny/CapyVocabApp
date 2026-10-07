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
    'capy-home-h2a-postgres-' + [guid]::NewGuid()
)
$null = New-Item -ItemType Directory -Path $testRoot
$dataRoot = Join-Path $testRoot 'data'
$startAttempted = $false

try {
    $output = (& (Join-Path $PostgresBin 'initdb.exe') `
        -D $dataRoot -U capy_h2a_admin -A trust `
        --encoding=UTF8 --no-locale 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Disposable PostgreSQL initdb failed.' }

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
            '-o', ('"-h 127.0.0.1 -p {0}"' -f $port),
            '-w', '-t', '30', 'start'
        )
    if (-not $startup.WaitForExit(40000)) {
        throw 'Disposable PostgreSQL startup exceeded its deadline.'
    }
    if ($startup.ExitCode -ne 0) {
        $null = & (Join-Path $PostgresBin 'pg_ctl.exe') -D $dataRoot status 2>&1
        if ($LASTEXITCODE -ne 0) {
            $startupDetails = @(
                'startup.stdout',
                'startup.stderr',
                'server.log'
            ) | ForEach-Object {
                $logPath = Join-Path $testRoot $_
                if (Test-Path -LiteralPath $logPath) {
                    "[$_]`n$(Get-Content -LiteralPath $logPath -Raw)"
                }
            }
            throw "Disposable PostgreSQL startup failed:`n$($startupDetails -join "`n")"
        }
    }

    $arguments = @(
        '-X', '-h', '127.0.0.1', '-p', $port,
        '-U', 'capy_h2a_admin', '-d', 'postgres',
        '-v', 'ON_ERROR_STOP=1',
        '-f', (Join-Path $repoRoot 'supabase\tests\home_h2a_bootstrap.sql'),
        '-f', (Join-Path $repoRoot 'supabase\migrations\20260928120000_add_daily_mission_contract.sql'),
        '-f', (Join-Path $repoRoot 'supabase\tests\home_h2a_security.sql'),
        '-f', (Join-Path $repoRoot 'supabase\migrations\20260928130000_ensure_daily_mission.sql'),
        '-f', (Join-Path $repoRoot 'supabase\migrations\20260928140000_enable_users_realtime.sql'),
        '-f', (Join-Path $repoRoot 'supabase\tests\home_h2b_security.sql'),
        '-f', (Join-Path $repoRoot 'supabase\migrations\20260930160000_add_lesson_completion_sync.sql'),
        '-f', (Join-Path $repoRoot 'supabase\tests\home_h4_completion_sync_security.sql'),
        '-f', (Join-Path $repoRoot 'supabase\migrations\20261004120000_settle_lesson_rewards.sql'),
        '-f', (Join-Path $repoRoot 'supabase\tests\home_h5_reward_security.sql'),
        '-f', (Join-Path $repoRoot 'supabase\migrations\20261004130000_add_weekly_yuzu_leaderboard.sql'),
        '-f', (Join-Path $repoRoot 'supabase\tests\home_h5_leaderboard_security.sql')
    )
    $ErrorActionPreference = 'Continue'
    $sqlOutput = (& (Join-Path $PostgresBin 'psql.exe') @arguments 2>&1 |
        Out-String)
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($exitCode -ne 0) {
        throw "H2A SQL tests failed (synthetic data only):`n$sqlOutput"
    }
    $passes = [regex]::Matches($sqlOutput, 'PASS:').Count
    if ($passes -ne 58) {
        throw "Expected all 58 Home SQL checks; observed $passes."
    }

    [pscustomobject]@{
        status = 'VERIFIED'
        sql_checks = $passes
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
        }
    }
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = (Resolve-Path -LiteralPath $testRoot).Path
        $temporaryParent = [IO.Path]::GetFullPath(
            [IO.Path]::GetTempPath()
        ).TrimEnd('\') + '\'
        if (-not $resolved.StartsWith(
                $temporaryParent,
                [StringComparison]::OrdinalIgnoreCase
            ) -or [IO.Path]::GetFileName($resolved) -notlike
            'capy-home-h2a-postgres-*') {
            throw 'Refusing cleanup outside allocated H2A test directory.'
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
