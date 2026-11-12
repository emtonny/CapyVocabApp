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
    'capy-group-gt2-postgres-' + [guid]::NewGuid()
)
$null = New-Item -ItemType Directory -Path $testRoot
$dataRoot = Join-Path $testRoot 'data'
$startAttempted = $false

try {
    $output = (& (Join-Path $PostgresBin 'initdb.exe') `
        -D $dataRoot -U capy_gt2_admin -A trust `
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
            $details = @('startup.stdout', 'startup.stderr', 'server.log') |
                ForEach-Object {
                    $path = Join-Path $testRoot $_
                    if (Test-Path -LiteralPath $path) {
                        "[$_]`n$(Get-Content -LiteralPath $path -Raw)"
                    }
                }
            throw "Disposable PostgreSQL startup failed:`n$($details -join "`n")"
        }
    }

    $arguments = @(
        '-X', '-h', '127.0.0.1', '-p', $port,
        '-U', 'capy_gt2_admin', '-d', 'postgres',
        '-v', 'ON_ERROR_STOP=1',
        '-f', (Join-Path $repoRoot 'supabase\tests\group_gt1_bootstrap.sql'),
        '-f', (Join-Path $repoRoot 'supabase\migrations\20261013120000_add_teacher_identity_contract.sql'),
        '-f', (Join-Path $repoRoot 'supabase\migrations\20261013130000_harden_teacher_verification_service_auth.sql'),
        '-f', (Join-Path $repoRoot 'supabase\tests\group_gt2_bootstrap.sql'),
        '-f', (Join-Path $repoRoot 'supabase\migrations\20261013140000_add_learning_groups.sql'),
        '-f', (Join-Path $repoRoot 'supabase\tests\group_gt2_security.sql')
    )
    $ErrorActionPreference = 'Continue'
    $sqlOutput = (& (Join-Path $PostgresBin 'psql.exe') @arguments 2>&1 |
        Out-String)
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($exitCode -ne 0) {
        throw "GT2 SQL tests failed (synthetic data only):`n$sqlOutput"
    }
    $passes = [regex]::Matches($sqlOutput, 'PASS:').Count
    if ($passes -ne 40) {
        throw "Expected all 40 Group GT2 SQL checks; observed $passes."
    }

    $setupArguments = @(
        '-X', '-h', '127.0.0.1', '-p', $port,
        '-U', 'capy_gt2_admin', '-d', 'postgres',
        '-v', 'ON_ERROR_STOP=1',
        '-f', (Join-Path $repoRoot 'supabase\tests\group_gt2_concurrency_setup.sql')
    )
    $setupOutput = (& (Join-Path $PostgresBin 'psql.exe') @setupArguments 2>&1 |
        Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw "GT2 concurrency setup failed:`n$setupOutput"
    }

    $approvalPrefix = @(
        '-X', '-h', '127.0.0.1', '-p', $port,
        '-U', 'capy_gt2_admin', '-d', 'postgres',
        '-v', 'ON_ERROR_STOP=1',
        '-f', (Join-Path $repoRoot 'supabase\tests\group_gt2_concurrency_approve.sql')
    )
    $firstOut = Join-Path $testRoot 'approval-first.stdout'
    $firstErr = Join-Path $testRoot 'approval-first.stderr'
    $secondOut = Join-Path $testRoot 'approval-second.stdout'
    $secondErr = Join-Path $testRoot 'approval-second.stderr'
    $first = Start-Process `
        -FilePath (Join-Path $PostgresBin 'psql.exe') `
        -WindowStyle Hidden `
        -PassThru `
        -RedirectStandardOutput $firstOut `
        -RedirectStandardError $firstErr `
        -ArgumentList ($approvalPrefix + @(
            '-v', 'prelock=true',
            '-v', 'student_id=90000000-0000-4000-8000-000000000050',
            '-v', 'request_id=91000000-0000-4000-8000-000000000002'
        ))
    $lockObserved = $false
    foreach ($attempt in 1..100) {
        $lockCount = (& (Join-Path $PostgresBin 'psql.exe') `
            -X -A -t -h 127.0.0.1 -p $port `
            -U capy_gt2_admin -d postgres `
            -v ON_ERROR_STOP=1 `
            -c "SELECT COUNT(*) FROM pg_locks WHERE locktype = 'advisory' AND granted" `
            2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw "GT2 concurrency barrier query failed:`n$lockCount"
        }
        if ([int]$lockCount -gt 0) {
            $lockObserved = $true
            break
        }
        Start-Sleep -Milliseconds 25
    }
    if (-not $lockObserved) {
        throw 'First GT2 approval never acquired its advisory lock.'
    }
    $second = Start-Process `
        -FilePath (Join-Path $PostgresBin 'psql.exe') `
        -WindowStyle Hidden `
        -PassThru `
        -RedirectStandardOutput $secondOut `
        -RedirectStandardError $secondErr `
        -ArgumentList ($approvalPrefix + @(
            '-v', 'prelock=false',
            '-v', 'student_id=90000000-0000-4000-8000-000000000051',
            '-v', 'request_id=91000000-0000-4000-8000-000000000003'
        ))
    if (-not $first.WaitForExit(10000) -or -not $second.WaitForExit(10000)) {
        throw 'GT2 concurrent approval processes exceeded their deadline.'
    }
    $first.WaitForExit()
    $second.WaitForExit()
    $firstOutput = Get-Content -Raw $firstOut
    $firstError = Get-Content -Raw $firstErr
    if (-not [string]::IsNullOrWhiteSpace($firstError) -or
        $firstOutput -notmatch 'respond_learning_group_join' -or
        $firstOutput -notmatch '(?m)^ active\s*$' -or
        $firstOutput -notmatch '(?m)^COMMIT\s*$') {
        throw "First GT2 concurrent approval failed:`nstdout:`n$firstOutput`nstderr:`n$firstError"
    }
    $secondError = Get-Content -Raw $secondErr
    if ($secondError -notmatch 'group_student_limit_reached') {
        throw "Second GT2 concurrent approval did not fail at capacity:`nstdout:`n$(Get-Content -Raw $secondOut)`nstderr:`n$secondError"
    }

    $verifyArguments = @(
        '-X', '-h', '127.0.0.1', '-p', $port,
        '-U', 'capy_gt2_admin', '-d', 'postgres',
        '-v', 'ON_ERROR_STOP=1',
        '-f', (Join-Path $repoRoot 'supabase\tests\group_gt2_concurrency_verify.sql')
    )
    $ErrorActionPreference = 'Continue'
    $concurrencyOutput = (& (Join-Path $PostgresBin 'psql.exe') `
        @verifyArguments 2>&1 | Out-String)
    $concurrencyExitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($concurrencyExitCode -ne 0) {
        throw "GT2 concurrency verification failed:`n$concurrencyOutput"
    }
    $concurrencyPasses = [regex]::Matches(
        $concurrencyOutput,
        'PASS:'
    ).Count
    if ($concurrencyPasses -ne 3) {
        throw "Expected 3 GT2 concurrency checks; observed $concurrencyPasses."
    }
    [pscustomobject]@{
        status = 'VERIFIED'
        sql_checks = $passes + $concurrencyPasses
        concurrent_approvals = '1 succeeded, 1 rejected at cap'
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
            'capy-group-gt2-postgres-*') {
            throw 'Refusing cleanup outside allocated GT2 test directory.'
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
