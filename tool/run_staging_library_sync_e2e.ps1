param(
    [string]$ExpectedProjectName = "emtonny's Project",
    [string]$FlutterCommand = "flutter"
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $repoRoot

try {
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
        throw "Refusing live test: linked project is not the expected Staging project."
    }
    if ($linked[0].status -ne 'ACTIVE_HEALTHY') {
        throw "Refusing live test: Staging is not ACTIVE_HEALTHY."
    }
    $activeInOrganization = @(
        $projects | Where-Object {
            $_.organization_id -eq $linked[0].organization_id -and
            $_.status -eq 'ACTIVE_HEALTHY'
        }
    )
    if ($activeInOrganization.Count -gt 2) {
        throw 'Refusing live test: more than two active projects were detected.'
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
        throw 'Unable to obtain temporary Staging API credentials.'
    }
    $keys = ConvertFrom-Json -InputObject $keysJson
    $anon = @($keys | Where-Object {
        $_.name -eq 'anon' -or $_.id -eq 'anon'
    } | Select-Object -First 1)
    $service = @($keys | Where-Object {
        $_.name -eq 'service_role' -or $_.id -eq 'service_role'
    } | Select-Object -First 1)
    if ($anon.Count -ne 1 -or $service.Count -ne 1) {
        throw 'Required anon/service_role keys were not returned by Supabase CLI.'
    }
    $anonValue = if ($anon[0].api_key) { $anon[0].api_key } else { $anon[0].key }
    $serviceValue = if ($service[0].api_key) {
        $service[0].api_key
    } else {
        $service[0].key
    }
    if (-not $anonValue -or -not $serviceValue) {
        throw 'Supabase CLI returned an unsupported API-key shape.'
    }

    $env:CAPY_RUN_STAGING_SYNC_E2E = '1'
    $env:CAPY_STAGING_SUPABASE_URL = "https://$($linked[0].ref).supabase.co"
    $env:CAPY_STAGING_ANON_KEY = $anonValue
    $env:CAPY_STAGING_SERVICE_ROLE_KEY = $serviceValue

    Write-Host "Running Library sync E2E against verified Staging target..."
    & $FlutterCommand test --no-pub `
        test/features/library/data/remote/library_sync_staging_e2e_test.dart `
        --reporter expanded
    if ($LASTEXITCODE -ne 0) {
        throw 'Staging Library sync E2E failed.'
    }
    Write-Host 'Staging Library sync E2E passed and cleanup assertions passed.'
}
finally {
    Remove-Item Env:CAPY_RUN_STAGING_SYNC_E2E -ErrorAction SilentlyContinue
    Remove-Item Env:CAPY_STAGING_SUPABASE_URL -ErrorAction SilentlyContinue
    Remove-Item Env:CAPY_STAGING_ANON_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:CAPY_STAGING_SERVICE_ROLE_KEY -ErrorAction SilentlyContinue
    Pop-Location
}
