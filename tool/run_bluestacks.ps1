param(
    [int]$Port,
    [switch]$Release,
    [switch]$Staging
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

function Find-Adb {
    $candidates = @()
    if ($env:ANDROID_HOME) {
        $candidates += Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
    }
    if ($env:ANDROID_SDK_ROOT) {
        $candidates += Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe'
    }
    if ($env:LOCALAPPDATA) {
        $candidates += Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    }
    if ($env:USERPROFILE) {
        $candidates += Join-Path $env:USERPROFILE 'AppData\Local\Android\Sdk\platform-tools\adb.exe'
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    $command = Get-Command adb -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw 'adb.exe not found. Install Android SDK Platform-Tools or Android Studio.'
}

function Get-ConnectedBlueStacksDevice([string]$adbPath) {
    $portsToTry = if ($Port) {
        @($Port)
    } else {
        @(5555, 5556, 5565, 5566, 5575, 5585)
    }

    foreach ($candidatePort in $portsToTry) {
        $endpoint = "127.0.0.1:$candidatePort"
        & $adbPath connect $endpoint | Out-Host
        $pattern = "^$([regex]::Escape($endpoint))\s+device$"
        $deviceLine = (& $adbPath devices | Select-String -Pattern $pattern).Line
        if ($deviceLine) {
            return $endpoint
        }
    }

    return $null
}

$adb = Find-Adb
$adbDirectory = Split-Path -Parent $adb
$env:Path = "$adbDirectory;$env:Path"

if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'assets\config\client.config'))) {
    throw 'Missing assets/config/client.config. Create the Supabase client config before running the app.'
}

Write-Host 'Connecting to BlueStacks through ADB...' -ForegroundColor Cyan
$device = Get-ConnectedBlueStacksDevice $adb
if (-not $device) {
    Write-Host ''
    Write-Host 'BlueStacks was not found through ADB.' -ForegroundColor Yellow
    Write-Host '1. Open BlueStacks and enable Android Debug Bridge in Settings > Advanced.'
    Write-Host '2. If it uses another port, retry with: .\tool\run_bluestacks.ps1 -Port <port>'
    throw 'ADB could not connect to BlueStacks.'
}

Write-Host "Connected: $device" -ForegroundColor Green
flutter pub get

$defineFile = $null
try {
    $runArguments = @('run', '-d', $device, '--no-dds')
    if ($Release) {
        $runArguments += '--release'
    }
    if ($Staging) {
        Write-Host 'Fetching Staging configuration from Supabase CLI...' -ForegroundColor Cyan
        $stagingRef = 'nxteaznowkfennxpqjmt'
        $keysJson = (& npx.cmd supabase projects api-keys --project-ref $stagingRef --reveal --output json | Out-String)
        if ($LASTEXITCODE -ne 0) {
            throw 'Unable to obtain Staging API credentials.'
        }
        $keys = ConvertFrom-Json -InputObject $keysJson
        $anon = @($keys | Where-Object { $_.name -eq 'anon' -or $_.id -eq 'anon' } | Select-Object -First 1)
        $anonValue = if ($anon[0].api_key) { $anon[0].api_key } else { $anon[0].key }
        $defineFile = Join-Path ([IO.Path]::GetTempPath()) ('capy_staging_bluestacks_{0}.json' -f [Guid]::NewGuid().ToString('N'))
        $defines = [ordered]@{
            SUPABASE_URL = "https://$stagingRef.supabase.co"
            SUPABASE_ANON_KEY = $anonValue
            LIBRARY_SYNC_ENABLED = $true
            CHAT_RELAY_ENABLED = $true
        } | ConvertTo-Json
        [IO.File]::WriteAllText($defineFile, $defines, (New-Object Text.UTF8Encoding($false)))
        $runArguments += "--dart-define-from-file=$defineFile"
    }

    Write-Host 'Building and running Capy Vocab...' -ForegroundColor Cyan
    flutter @runArguments
}
finally {
    if ($defineFile -and (Test-Path -LiteralPath $defineFile)) {
        Remove-Item -LiteralPath $defineFile -Force
    }
}
