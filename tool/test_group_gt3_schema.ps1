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
    'capy-group-gt3-postgres-' + [guid]::NewGuid()
)
$null = New-Item -ItemType Directory -Path $testRoot
$dataRoot = Join-Path $testRoot 'data'
$startAttempted = $false

try {
    $output = (& (Join-Path $PostgresBin 'initdb.exe') `
        -D $dataRoot -U capy_gt3_admin -A trust `
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
            '-o', ('"-h 127.0.0.1 -p {0} -c wal_level=logical"' -f $port),
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
        '-U', 'capy_gt3_admin', '-d', 'postgres',
        '-v', 'ON_ERROR_STOP=1',
        '-f', (Join-Path $repoRoot 'supabase\tests\group_gt1_bootstrap.sql'),
        '-f', (Join-Path $repoRoot 'supabase\migrations\20261013120000_add_teacher_identity_contract.sql'),
        '-f', (Join-Path $repoRoot 'supabase\migrations\20261013130000_harden_teacher_verification_service_auth.sql'),
        '-f', (Join-Path $repoRoot 'supabase\tests\group_gt3_bootstrap.sql'),
        '-f', (Join-Path $repoRoot 'supabase\migrations\20260915120000_add_operational_chat_security.sql'),
        '-f', (Join-Path $repoRoot 'supabase\migrations\20260918120000_add_chat_translation_queue_claim.sql'),
        '-f', (Join-Path $repoRoot 'supabase\tests\chat_translation_wakeup_bootstrap.sql'),
        '-f', (Join-Path $repoRoot 'supabase\migrations\20260918130000_add_chat_translation_worker_wakeup.sql'),
        '-f', (Join-Path $repoRoot 'supabase\migrations\20260920120000_add_chat_correction_resolution_audit.sql'),
        '-f', (Join-Path $repoRoot 'supabase\migrations\20260920130000_add_chat_manual_span_annotations.sql'),
        '-f', (Join-Path $repoRoot 'supabase\migrations\20260921120000_add_vilao_chat_translation_v2.sql'),
        '-f', (Join-Path $repoRoot 'supabase\migrations\20261013140000_add_learning_groups.sql'),
        '-f', (Join-Path $repoRoot 'supabase\migrations\20261017120000_add_learning_group_chat.sql'),
        '-f', (Join-Path $repoRoot 'supabase\migrations\20261021110000_add_gemini_chat_translation_v3.sql'),
        '-f', (Join-Path $repoRoot 'supabase\tests\group_gt3_security.sql')
    )
    $ErrorActionPreference = 'Continue'
    $sqlOutput = (& (Join-Path $PostgresBin 'psql.exe') @arguments 2>&1 |
        Out-String)
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($exitCode -ne 0) {
        throw "GT3 SQL tests failed (synthetic data only):`n$sqlOutput"
    }
    $passes = [regex]::Matches($sqlOutput, 'PASS:').Count
    if ($passes -ne 20) {
        throw "Expected all 20 Group GT3 SQL checks; observed $passes."
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
            'capy-group-gt3-postgres-*') {
            throw 'Refusing cleanup outside allocated GT3 test directory.'
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
