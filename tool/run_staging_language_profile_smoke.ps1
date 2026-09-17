#requires -Version 7.0
# Two isolated fixture accounts; never modifies the demo user or Production.
$ErrorActionPreference = 'Stop'
$stagingRef = 'nxteaznowkfennxpqjmt'
$baseUrl = "https://$stagingRef.supabase.co"
$runId = [guid]::NewGuid().ToString('N')
$scope = 'c1_language_profile_smoke'
$fixtureIds = [Collections.Generic.HashSet[string]]::new()
$accounts = [Collections.Generic.List[object]]::new()
$checks = [Collections.Generic.List[string]]::new()
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Invoke-StagingRequest {
    param([string]$Method, [string]$Path, [hashtable]$Headers, [object]$Body)
    try {
        $request = @{Method=$Method; Uri="$baseUrl$Path"; Headers=$Headers; TimeoutSec=30; SkipHttpErrorCheck=$true}
        if ($null -ne $Body) {
            $request.ContentType = 'application/json'
            $request.Body = $Body | ConvertTo-Json -Depth 8 -Compress
        }
        $response = Invoke-WebRequest @request
        $json = if ($response.Content) { ConvertFrom-Json $response.Content -NoEnumerate } else { $null }
        return [pscustomobject]@{Status=[int]$response.StatusCode; Json=$json}
    }
    catch { throw 'Staging smoke transport/JSON failure; response content and credentials were not logged.' }
}

function Assert-Status($Response, [int[]]$Expected, [string]$Label) {
    if ($Response.Status -notin $Expected) {
        $code = if ($Response.Json.code -match '^[a-zA-Z0-9_]+$') { $Response.Json.code } else { 'unavailable' }
        throw "$Label failed: HTTP $($Response.Status), code=$code."
    }
}

function Assert-Empty($Response, [string]$Label) {
    Assert-Status $Response @(200) $Label
    if ($null -eq $Response.Json -or $Response.Json -isnot [array] -or $Response.Json.Count -ne 0) {
        throw "$Label failed: expected an empty JSON array."
    }
}

function Get-Fixtures {
    $found = [Collections.Generic.List[object]]::new()
    for ($page = 1; $page -le 20; $page++) {
        $response = Invoke-StagingRequest GET "/auth/v1/admin/users?page=$page&per_page=100" $adminHeaders
        Assert-Status $response @(200) 'Fixture inventory'
        $users = @($response.Json.users)
        foreach ($user in $users) {
            if ($user.user_metadata.test_scope -eq $scope -and $user.user_metadata.run_id -eq $runId) {
                $found.Add($user)
            }
        }
        if ($users.Count -lt 100) { return $found.ToArray() }
    }
    throw 'Fixture inventory was truncated; refusing broad cleanup.'
}

Push-Location $repoRoot
try {
    $projectsText = (& npx.cmd supabase projects list --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to verify Staging.' }
    $project = @(ConvertFrom-Json $projectsText | Where-Object { $_.ref -eq $stagingRef })
    if ($project.Count -ne 1 -or $project[0].name -ne "emtonny's Project" -or
        $project[0].status -ne 'ACTIVE_HEALTHY' -or -not $project[0].linked) {
        throw 'Refusing smoke: unexpected linked target.'
    }
    $keysText = (& npx.cmd supabase projects api-keys --project-ref $stagingRef --reveal --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to obtain Staging API credentials.' }
    $keys = @(ConvertFrom-Json $keysText)
    $publicKey = @($keys | Where-Object { $_.type -eq 'publishable' -or $_.name -eq 'anon' -or $_.id -eq 'anon' } | Select-Object -First 1)
    $adminKey = @($keys | Where-Object { $_.type -eq 'secret' } | Select-Object -First 1)
    if ($adminKey.Count -eq 0) {
        $adminKey = @($keys | Where-Object { $_.name -eq 'service_role' -or $_.id -eq 'service_role' } | Select-Object -First 1)
    }
    if ($publicKey.Count -ne 1 -or $adminKey.Count -ne 1) { throw 'Required Staging keys were not returned.' }
    $anonValue = if ($publicKey[0].api_key) { $publicKey[0].api_key } else { $publicKey[0].key }
    $adminValue = if ($adminKey[0].api_key) { $adminKey[0].api_key } else { $adminKey[0].key }
    if (-not $anonValue -or -not $adminValue) { throw 'Unsupported API credential shape.' }
    $anonHeaders = @{apikey=$anonValue; 'User-Agent'='capy-c1-smoke/1.0'}
    $adminHeaders = @{apikey=$adminValue; Authorization="Bearer $adminValue"; 'User-Agent'='capy-c1-smoke/1.0'}
    $baseline = Invoke-StagingRequest GET '/rest/v1/user_language_profiles?select=user_id' $adminHeaders
    Assert-Status $baseline @(200) 'Language schema baseline'
    $baselineIds = @($baseline.Json | ForEach-Object { $_.user_id } | Sort-Object)

    for ($index = 0; $index -lt 2; $index++) {
        $email = "c1-$runId-$index@example.com"
        $password = 'C1!' + [guid]::NewGuid().ToString('N')
        $created = Invoke-StagingRequest POST '/auth/v1/admin/users' $adminHeaders @{
            email=$email; password=$password; email_confirm=$true
            user_metadata=@{test_scope=$scope; run_id=$runId}
        }
        Assert-Status $created @(200, 201) 'Fixture creation'
        $id = [string]$created.Json.id
        if ($id -notmatch '^[0-9a-f-]{36}$') { throw 'Fixture identity was missing.' }
        $null = $fixtureIds.Add($id)
        $login = Invoke-StagingRequest POST '/auth/v1/token?grant_type=password' $anonHeaders @{email=$email; password=$password}
        Assert-Status $login @(200) 'Fixture sign-in'
        if ($login.Json.user.id -ne $id -or -not $login.Json.access_token) { throw 'Fixture session mismatch.' }
        $ownerHeaders = @{apikey=$anonValue; Authorization="Bearer $($login.Json.access_token)"; Prefer='return=representation'; 'User-Agent'='capy-c1-smoke/1.0'}
        $rpc = @{
            p_display_name="C1 fixture $index"; p_username=('c1' + $runId.Substring(0, 14) + $index)
            p_age=25; p_phone=('0' + (Get-Random -Minimum 100000000 -Maximum 1000000000))
            p_account_role='personal'; p_reminder_time='22:00'; p_study_end_time='02:00'; p_daily_target_words=10
            p_native_language_code=($(if ($index -eq 0) { 'vi' } else { 'en' }))
            p_learning_language_code=($(if ($index -eq 0) { 'en' } else { 'vi' }))
            p_proficiency_level='beginner'
        }
        $accounts.Add([pscustomobject]@{Id=$id; Headers=$ownerHeaders; Rpc=$rpc})
        Assert-Empty (Invoke-StagingRequest GET "/rest/v1/user_language_profiles?user_id=eq.$id&select=user_id" $ownerHeaders) 'Unknown profile'
        $completed = Invoke-StagingRequest POST '/rest/v1/rpc/complete_onboarding' $ownerHeaders $rpc
        Assert-Status $completed @(200) 'New onboarding RPC'
        if ($completed.Json -ne $true) { throw 'Onboarding RPC did not complete.' }
    }
    $checks.Add('two_accounts_unknown_then_atomic_onboarding')

    $a = $accounts[0]; $b = $accounts[1]
    foreach ($account in $accounts) {
        $own = Invoke-StagingRequest GET "/rest/v1/user_language_profiles?user_id=eq.$($account.Id)&select=*" $account.Headers
        Assert-Status $own @(200) 'Owner profile read'
        if ($own.Json.Count -ne 1 -or $own.Json[0].native_language_code -ne $account.Rpc.p_native_language_code -or
            $own.Json[0].learning_language_code -ne $account.Rpc.p_learning_language_code) { throw 'Owner language pair mismatch.' }
    }
    Assert-Empty (Invoke-StagingRequest GET "/rest/v1/user_language_profiles?user_id=eq.$($b.Id)&select=user_id" $a.Headers) 'Cross-owner read'
    $crossWrite = Invoke-StagingRequest POST '/rest/v1/user_language_profiles?on_conflict=user_id' $a.Headers @{
        user_id=$b.Id; native_language_code='vi'; learning_language_code='en'; proficiency_level='advanced'
    }
    Assert-Status $crossWrite @(403) 'Cross-owner write rejection'
    Assert-Status (Invoke-StagingRequest GET '/rest/v1/user_language_profiles?select=user_id' $anonHeaders) @(401, 403) 'Anonymous rejection'
    $checks.Add('owner_rls_cross_read_write_and_anon_rejection')

    $invalid = $a.Rpc.Clone()
    $invalid.p_display_name = 'Must not commit'
    $invalid.p_learning_language_code = $invalid.p_native_language_code
    Assert-Status (Invoke-StagingRequest POST '/rest/v1/rpc/complete_onboarding' $a.Headers $invalid) @(400) 'Invalid pair RPC rejection'
    $user = Invoke-StagingRequest GET "/rest/v1/users?id=eq.$($a.Id)&select=display_name,onboarding_completed" $a.Headers
    Assert-Status $user @(200) 'Atomic rollback read'
    if ($user.Json[0].display_name -ne $a.Rpc.p_display_name -or -not $user.Json[0].onboarding_completed) { throw 'Invalid RPC changed the user profile.' }
    $checks.Add('invalid_pair_rpc_rolls_back')
    Assert-Status (Invoke-StagingRequest PATCH "/rest/v1/user_language_profiles?user_id=eq.$($a.Id)" $a.Headers @{
        native_language_code='en'; learning_language_code='en'
    }) @(400) 'Invalid table language pair rejection'
    $checks.Add('direct_table_language_constraint')

    $updated = Invoke-StagingRequest PATCH "/rest/v1/user_language_profiles?user_id=eq.$($a.Id)" $a.Headers @{
        proficiency_level='intermediate'; updated_at='2000-01-01T00:00:00Z'
    }
    Assert-Status $updated @(200) 'Server timestamp update'
    if ([DateTime]$updated.Json[0].updated_at -lt [DateTime]$updated.Json[0].created_at -or
        [DateTime]$updated.Json[0].updated_at -lt [DateTime]::UtcNow.AddMinutes(-5)) { throw 'Server timestamp was not authoritative.' }
    $checks.Add('server_timestamp_ignores_device_clock')

    $legacy = $b.Rpc.Clone()
    $legacy.Remove('p_native_language_code'); $legacy.Remove('p_learning_language_code'); $legacy.Remove('p_proficiency_level')
    Assert-Status (Invoke-StagingRequest POST '/rest/v1/rpc/complete_onboarding' $b.Headers $legacy) @(200) 'Legacy onboarding RPC'
    $unchanged = Invoke-StagingRequest GET "/rest/v1/user_language_profiles?user_id=eq.$($b.Id)&select=native_language_code,learning_language_code" $b.Headers
    Assert-Status $unchanged @(200) 'Legacy language preservation'
    if ($unchanged.Json[0].native_language_code -ne 'en' -or $unchanged.Json[0].learning_language_code -ne 'vi') { throw 'Legacy RPC changed language preferences.' }
    $checks.Add('legacy_eight_argument_rpc_compatible')
}
finally {
    try {
        if ($adminHeaders) {
            # Also find an account created successfully before a transport timeout.
            foreach ($fixture in @(Get-Fixtures)) { $null = $fixtureIds.Add([string]$fixture.id) }
            foreach ($id in $fixtureIds) {
                $fixture = Invoke-StagingRequest GET "/auth/v1/admin/users/$id" $adminHeaders
                Assert-Status $fixture @(200) 'Cleanup identity check'
                if ($fixture.Json.user_metadata.test_scope -ne $scope -or $fixture.Json.user_metadata.run_id -ne $runId) {
                    throw 'Refusing cleanup: identity did not match this exact smoke run.'
                }
                Assert-Status (Invoke-StagingRequest DELETE "/auth/v1/admin/users/$id" $adminHeaders) @(200, 204) 'Fixture deletion'
            }
            if (@(Get-Fixtures).Count -ne 0) { throw 'Fixture Auth cleanup failed.' }
            $after = Invoke-StagingRequest GET '/rest/v1/user_language_profiles?select=user_id' $adminHeaders
            Assert-Status $after @(200) 'Cascading profile cleanup'
            $afterIds = @($after.Json | ForEach-Object { $_.user_id } | Sort-Object)
            if (($baselineIds -join ',') -ne ($afterIds -join ',')) { throw 'Fixture profile cleanup or baseline isolation failed.' }
            $checks.Add('auth_fixture_and_profile_cleanup_baseline_preserved')
        }
    }
    finally {
        $keysText=$null; $keys=$null; $anonValue=$null; $adminValue=$null
        $anonHeaders=$null; $adminHeaders=$null; $accounts.Clear()
        Pop-Location
    }
}
[pscustomobject]@{status='VERIFIED'; project_ref=$stagingRef; checks=$checks.ToArray(); fixture_count_remaining=0} | ConvertTo-Json -Depth 4
