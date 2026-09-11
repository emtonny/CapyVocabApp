param(
    [string]$ExpectedProjectName = "emtonny's Project",
    [string]$FlutterCommand = "flutter",
    [int]$StartupSeconds = 10,
    [ValidateSet('windows', 'android-build', 'android-device')]
    [string]$Target = 'windows',
    [string]$DeviceId = ''
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$defineFile = $null
$appProcess = $null
$previousDebugEnvironment = $env:DEBUG
Push-Location $repoRoot

try {
    # Gradle's Windows wrapper treats any DEBUG value as a request to echo the
    # complete command line, which would expose dart-define values in logs.
    Remove-Item Env:DEBUG -ErrorAction SilentlyContinue

    $projectsJson = (& npx.cmd supabase projects list --output json | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to list Supabase projects.'
    }
    $projects = ConvertFrom-Json -InputObject $projectsJson
    $linked = @($projects | Where-Object { $_.linked -eq $true })
    if ($linked.Count -ne 1) {
        throw "Expected exactly one linked Supabase project; found $($linked.Count)."
    }
    if ($linked[0].name -ne $ExpectedProjectName) {
        throw 'Refusing device smoke: linked project is not expected Staging.'
    }
    if ($linked[0].status -ne 'ACTIVE_HEALTHY') {
        throw 'Refusing device smoke: Staging is not ACTIVE_HEALTHY.'
    }
    $activeInOrganization = @(
        $projects | Where-Object {
            $_.organization_id -eq $linked[0].organization_id -and
            $_.status -eq 'ACTIVE_HEALTHY'
        }
    )
    if ($activeInOrganization.Count -gt 2) {
        throw 'Refusing device smoke: more than two active projects detected.'
    }

    & npx.cmd supabase db push --linked --dry-run | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw 'Staging migration dry-run failed.'
    }

    $keysJson = (
        & npx.cmd supabase projects api-keys `
            --project-ref $linked[0].ref `
            --output json | Out-String
    )
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to obtain the Staging publishable credential.'
    }
    $keys = ConvertFrom-Json -InputObject $keysJson
    $anon = @($keys | Where-Object {
        $_.name -eq 'anon' -or $_.id -eq 'anon'
    } | Select-Object -First 1)
    if ($anon.Count -ne 1) {
        throw 'Supabase CLI did not return an anon credential.'
    }
    $anonValue = if ($anon[0].api_key) { $anon[0].api_key } else { $anon[0].key }
    if (-not $anonValue) {
        throw 'Supabase CLI returned an unsupported anon-key shape.'
    }

    $defineFile = Join-Path ([IO.Path]::GetTempPath()) (
        'capy_vocab_staging_smoke_{0}.json' -f [Guid]::NewGuid().ToString('N')
    )
    $defines = [ordered]@{
        SUPABASE_URL = "https://$($linked[0].ref).supabase.co"
        SUPABASE_ANON_KEY = $anonValue
        LIBRARY_SYNC_ENABLED = $true
    } | ConvertTo-Json
    [IO.File]::WriteAllText(
        $defineFile,
        $defines,
        (New-Object Text.UTF8Encoding($false))
    )

    if ($Target -eq 'android-build') {
        Write-Host 'Building Android Staging APK with Library sync enabled...'
        & $FlutterCommand build apk --debug --no-pub `
            "--dart-define-from-file=$defineFile"
        if ($LASTEXITCODE -ne 0) {
            throw 'Android Staging build verification failed.'
        }
        $apk = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-debug.apk'
        if (-not (Test-Path -LiteralPath $apk)) {
            throw 'Android build completed without the expected APK.'
        }
        Write-Host 'PASS: Android Staging APK compiled with sync build flag enabled.'
        return
    }

    if ($Target -eq 'android-device') {
        if ([string]::IsNullOrWhiteSpace($DeviceId)) {
            throw 'DeviceId is required for an Android device smoke run.'
        }
        Write-Host "Installing and running Staging on Android device $DeviceId..."
        & $FlutterCommand run --debug --no-pub `
            -d $DeviceId `
            "--dart-define-from-file=$defineFile"
        if ($LASTEXITCODE -ne 0) {
            throw 'Android Staging device smoke failed.'
        }
        Write-Host 'PASS: Flutter device session ended cleanly.'
        return
    }

    Write-Host 'Building Windows Staging smoke artifact with Library sync enabled...'
    & $FlutterCommand build windows --debug --no-pub `
        "--dart-define-from-file=$defineFile"
    if ($LASTEXITCODE -ne 0) {
        throw 'Windows Staging smoke build failed.'
    }

    $executable = Join-Path $repoRoot 'build\windows\x64\runner\Debug\capy_vocab.exe'
    $resolvedExecutable = (Resolve-Path $executable).Path
    if (-not $resolvedExecutable.StartsWith($repoRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Refusing to launch an executable outside the repository.'
    }

    Write-Host "Launching native Staging artifact for $StartupSeconds seconds..."
    $appProcess = Start-Process `
        -FilePath $resolvedExecutable `
        -WorkingDirectory (Split-Path $resolvedExecutable) `
        -WindowStyle Hidden `
        -PassThru
    Start-Sleep -Seconds $StartupSeconds
    $appProcess.Refresh()
    if ($appProcess.HasExited) {
        throw "Staging artifact exited early with code $($appProcess.ExitCode)."
    }

    Write-Host 'PASS: native Staging artifact stayed alive with sync build flag enabled.'
}
finally {
    if ($appProcess -and -not $appProcess.HasExited) {
        Stop-Process -Id $appProcess.Id -Force
    }
    if ($defineFile -and (Test-Path -LiteralPath $defineFile)) {
        Remove-Item -LiteralPath $defineFile -Force
    }
    if ($null -eq $previousDebugEnvironment) {
        Remove-Item Env:DEBUG -ErrorAction SilentlyContinue
    } else {
        $env:DEBUG = $previousDebugEnvironment
    }
    Pop-Location
}
