#requires -Version 7.0
# Two isolated fixture accounts; never modifies demo users or Production.
param(
    [string]$ExpectedProjectName = "emtonny's Project"
)

$ErrorActionPreference = 'Stop'
$stagingRef = 'nxteaznowkfennxpqjmt'
$baseUrl = "https://$stagingRef.supabase.co"
$runId = [guid]::NewGuid().ToString('N')
$scope = 'group_gt1_teacher_identity_smoke'
$fixtureIds = [Collections.Generic.List[string]]::new()
$checks = [Collections.Generic.List[string]]::new()
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Request {
    param([string]$Method, [string]$Path, [hashtable]$Headers, [object]$Body)
    try {
        $request = @{
            Method = $Method
            Uri = "$baseUrl$Path"
            Headers = $Headers
            TimeoutSec = 30
            SkipHttpErrorCheck = $true
        }
        if ($null -ne $Body) {
            $request.ContentType = 'application/json'
            $request.Body = $Body | ConvertTo-Json -Depth 8 -Compress
        }
        $response = Invoke-WebRequest @request
        $json = if ($response.Content) {
            ConvertFrom-Json $response.Content -NoEnumerate
        } else {
            $null
        }
        [pscustomobject]@{Status=[int]$response.StatusCode; Json=$json}
    }
    catch {
        throw 'GT1 Staging smoke transport/JSON failure; credentials and response body were not logged.'
    }
}

function Status {
    param($Response, [int[]]$Expected, [string]$Label)
    if ($Response.Status -notin $Expected) {
        $code = if ($Response.Json.code -match '^[a-zA-Z0-9_]+$') {
            $Response.Json.code
        } else {
            'unavailable'
        }
        throw "$Label failed: HTTP $($Response.Status), code=$code."
    }
}

function Get-ScopeFixtureCount {
    param([hashtable]$Headers)
    $count = 0
    for ($page = 1; $page -le 20; $page++) {
        $response = Request GET "/auth/v1/admin/users?page=$page&per_page=100" `
            $Headers $null
        Status $response @(200) 'Fixture inventory'
        $users = @($response.Json.users)
        $count += @($users | Where-Object {
            $_.user_metadata.test_scope -eq $scope
        }).Count
        if ($users.Count -lt 100) { return $count }
    }
    throw 'Fixture inventory was truncated; refusing to claim cleanup.'
}

function New-Fixture {
    param(
        [string]$Label,
        [hashtable]$AdminHeaders,
        [hashtable]$AnonHeaders
    )
    $email = "gt1-$Label-$runId@example.com"
    $password = 'GT1!' + [guid]::NewGuid().ToString('N')
    $created = Request POST '/auth/v1/admin/users' $AdminHeaders @{
        email = $email
        password = $password
        email_confirm = $true
        user_metadata = @{
            test_scope = $scope
            run_id = $runId
            fixture = $Label
        }
    }
    Status $created @(200, 201) "$Label fixture creation"
    $id = [string]$created.Json.id
    if ($id -notmatch '^[0-9a-f-]{36}$') {
        throw "$Label fixture identity was missing."
    }
    $fixtureIds.Add($id)

    $login = Request POST '/auth/v1/token?grant_type=password' $AnonHeaders @{
        email = $email
        password = $password
    }
    Status $login @(200) "$Label fixture sign-in"
    if ($login.Json.user.id -ne $id -or -not $login.Json.access_token) {
        throw "$Label fixture session mismatch."
    }
    [pscustomobject]@{
        Id = $id
        Headers = @{
            apikey = $AnonHeaders.apikey
            Authorization = "Bearer $($login.Json.access_token)"
            Prefer = 'return=representation'
            'User-Agent' = 'capy-group-gt1-smoke/1.0'
        }
    }
}

function Complete-Onboarding {
    param($Fixture, [string]$Role, [string]$Username)
    $response = Request POST '/rest/v1/rpc/complete_onboarding' `
        $Fixture.Headers @{
            p_display_name = "GT1 $Role fixture"
            p_username = $Username
            p_age = 30
            p_phone = ''
            p_account_role = $Role
            p_interface_locale = 'vi-VN'
            p_learning_locale = 'en-US'
            p_reminder_time = '20:00'
            p_study_end_time = '21:00'
            p_daily_target_words = 10
            p_native_language_code = 'vi'
            p_learning_language_code = 'en'
            p_proficiency_level = 'beginner'
        }
    Status $response @(200) "$Role onboarding"
    if ($response.Json -ne $true) { throw "$Role onboarding returned false." }
}

Push-Location $repoRoot
try {
    $projectsText = (& npx.cmd supabase projects list --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to verify Staging.' }
    $project = @(ConvertFrom-Json $projectsText | Where-Object {
        $_.ref -eq $stagingRef
    })
    if ($project.Count -ne 1 -or $project[0].name -cne $ExpectedProjectName -or
        $project[0].status -ne 'ACTIVE_HEALTHY' -or -not $project[0].linked) {
        throw 'Refusing GT1 smoke: linked target is not exact healthy Staging.'
    }

    $dryRunText = (& npx.cmd supabase db push --project-ref $stagingRef `
        --dry-run | Out-String)
    $dryRun = if ($LASTEXITCODE -eq 0) {
        ConvertFrom-Json $dryRunText
    } else {
        $null
    }
    if ($null -eq $dryRun -or $dryRun.upToDate -ne $true) {
        throw 'Refusing GT1 smoke: Staging migration history is not up to date.'
    }

    $keysText = (& npx.cmd supabase projects api-keys `
        --project-ref $stagingRef --reveal --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to obtain Staging API credentials.' }
    $keys = @(ConvertFrom-Json $keysText)
    $publicKey = @($keys | Where-Object {
        $_.type -eq 'publishable' -or $_.name -eq 'anon' -or $_.id -eq 'anon'
    } | Select-Object -First 1)
    $adminKey = @($keys | Where-Object {
        $_.type -eq 'secret'
    } | Select-Object -First 1)
    if ($adminKey.Count -eq 0) {
        $adminKey = @($keys | Where-Object {
            $_.name -eq 'service_role' -or $_.id -eq 'service_role'
        } | Select-Object -First 1)
    }
    if ($publicKey.Count -ne 1 -or $adminKey.Count -ne 1) {
        throw 'Required Staging credentials were not returned.'
    }
    $anonValue = if ($publicKey[0].api_key) {
        $publicKey[0].api_key
    } else {
        $publicKey[0].key
    }
    $adminValue = if ($adminKey[0].api_key) {
        $adminKey[0].api_key
    } else {
        $adminKey[0].key
    }
    if (-not $anonValue -or -not $adminValue) {
        throw 'Unsupported API credential shape.'
    }
    $agent = 'capy-group-gt1-smoke/1.0'
    $anonHeaders = @{apikey=$anonValue; 'User-Agent'=$agent}
    $adminHeaders = @{
        apikey = $adminValue
        Authorization = "Bearer $adminValue"
        Prefer = 'return=representation'
        'User-Agent' = $agent
    }
    if ((Get-ScopeFixtureCount $adminHeaders) -ne 0) {
        throw 'Pre-existing GT1 smoke fixtures require manual audit.'
    }

    $teacher = New-Fixture 'teacher' $adminHeaders $anonHeaders
    $outsider = New-Fixture 'outsider' $adminHeaders $anonHeaders
    Complete-Onboarding $teacher 'teacher' ('gt1t' + $runId.Substring(0, 14))
    Complete-Onboarding $outsider 'personal' ('gt1p' + $runId.Substring(0, 14))

    $pending = Request GET (
        "/rest/v1/teacher_profiles?user_id=eq.$($teacher.Id)&select=verification_status"
    ) $teacher.Headers $null
    Status $pending @(200) 'Teacher pending profile read'
    if (@($pending.Json).Count -ne 1 -or
        $pending.Json[0].verification_status -ne 'pending') {
        throw 'Teacher did not receive exactly one pending profile.'
    }
    $pendingAuth = Request POST `
        '/rest/v1/rpc/is_current_user_verified_teacher' `
        $teacher.Headers @{}
    Status $pendingAuth @(200) 'Pending teacher authorization read'
    if ($pendingAuth.Json -ne $false) {
        throw 'Self-selected pending teacher received authorization.'
    }
    $checks.Add('self_selected_teacher_is_pending_and_unauthorized')

    $selfVerify = Request POST '/rest/v1/rpc/set_teacher_verification' `
        $teacher.Headers @{
            p_teacher_user_id = $teacher.Id
            p_status = 'verified'
            p_reason_code = 'gt1_smoke'
        }
    Status $selfVerify @(401, 403, 404) 'Authenticated self-verification rejection'
    $directUpdate = Request PATCH (
        "/rest/v1/teacher_profiles?user_id=eq.$($teacher.Id)"
    ) $teacher.Headers @{verification_status='verified'}
    Status $directUpdate @(401, 403, 405) 'Direct verification update rejection'
    $checks.Add('authenticated_verification_mutations_rejected')

    $outsiderRead = Request GET (
        "/rest/v1/teacher_profiles?user_id=eq.$($teacher.Id)&select=user_id"
    ) $outsider.Headers $null
    Status $outsiderRead @(200) 'Outsider profile read'
    if (@($outsiderRead.Json).Count -ne 0) {
        throw 'Outsider read another user teacher profile.'
    }
    $checks.Add('teacher_profile_rls_hides_cross_account_rows')

    $verified = Request POST '/rest/v1/rpc/set_teacher_verification' `
        $adminHeaders @{
            p_teacher_user_id = $teacher.Id
            p_status = 'verified'
            p_reason_code = 'gt1_smoke'
        }
    Status $verified @(200) 'Service teacher verification'
    if ($verified.Json -ne $true) { throw 'Service verification returned false.' }
    $verifiedAuth = Request POST `
        '/rest/v1/rpc/is_current_user_verified_teacher' `
        $teacher.Headers @{}
    Status $verifiedAuth @(200) 'Verified teacher authorization read'
    if ($verifiedAuth.Json -ne $true) {
        throw 'Verified teacher did not receive authorization.'
    }
    $checks.Add('service_verification_grants_teacher_authorization')

    $serviceDirectUpdate = Request PATCH (
        "/rest/v1/teacher_profiles?user_id=eq.$($teacher.Id)"
    ) $adminHeaders @{verification_status='suspended'}
    Status $serviceDirectUpdate @(401, 403, 405) `
        'Service direct verification update rejection'
    $checks.Add('service_mutation_must_use_guarded_rpc')

    $suspended = Request POST '/rest/v1/rpc/set_teacher_verification' `
        $adminHeaders @{
            p_teacher_user_id = $teacher.Id
            p_status = 'suspended'
            p_reason_code = 'gt1_smoke'
        }
    Status $suspended @(200) 'Service teacher suspension'
    if ($suspended.Json -ne $true) { throw 'Service suspension returned false.' }
    $suspendedAuth = Request POST `
        '/rest/v1/rpc/is_current_user_verified_teacher' `
        $teacher.Headers @{}
    Status $suspendedAuth @(200) 'Suspended teacher authorization read'
    if ($suspendedAuth.Json -ne $false) {
        throw 'Suspended teacher retained authorization.'
    }
    $checks.Add('suspension_revokes_teacher_authorization')
}
finally {
    try {
        if ($adminHeaders) {
            foreach ($id in $fixtureIds) {
                $fixture = Request GET "/auth/v1/admin/users/$id" `
                    $adminHeaders $null
                Status $fixture @(200) 'Cleanup identity read'
                if ($fixture.Json.user_metadata.test_scope -ne $scope -or
                    $fixture.Json.user_metadata.run_id -ne $runId) {
                    throw 'Refusing cleanup: fixture identity does not match this run.'
                }
                Status (Request DELETE "/auth/v1/admin/users/$id" `
                    $adminHeaders $null) @(200, 204) 'Fixture deletion'
                $remaining = Request GET (
                    "/rest/v1/teacher_profiles?user_id=eq.$id&select=user_id"
                ) $adminHeaders $null
                Status $remaining @(200) 'Teacher profile cascade verification'
                if (@($remaining.Json).Count -ne 0) {
                    throw 'Teacher profile cascade cleanup failed.'
                }
            }
            if ((Get-ScopeFixtureCount $adminHeaders) -ne 0) {
                throw 'GT1 Auth fixture cleanup failed.'
            }
            $checks.Add('fixture_and_teacher_profile_cleanup')
        }
    }
    finally {
        $keysText=$null; $keys=$null; $anonValue=$null; $adminValue=$null
        $anonHeaders=$null; $adminHeaders=$null
        Pop-Location
    }
}

[pscustomobject]@{
    status = 'VERIFIED'
    project_ref = $stagingRef
    checks = $checks.ToArray()
    fixture_count_remaining = 0
} | ConvertTo-Json -Depth 4
