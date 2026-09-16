param(
    [int]$Port,
    [switch]$Release
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

$runArguments = @('run', '-d', $device, '--no-dds')
if ($Release) {
    $runArguments += '--release'
}

Write-Host 'Building and running Capy Vocab...' -ForegroundColor Cyan
flutter @runArguments
