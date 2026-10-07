#requires -Version 7.0
# One isolated fixture account; never modifies the demo user or Production.
param(
    [string]$ExpectedProjectName = "emtonny's Project"
)

$ErrorActionPreference = 'Stop'
$stagingRef = 'nxteaznowkfennxpqjmt'
$baseUrl = "https://$stagingRef.supabase.co"
$runId = [guid]::NewGuid().ToString('N')
$scope = 'home_h5_reward_leaderboard_smoke'
$fixtureId = $null
$fixtureBId = $null
$checks = [Collections.Generic.List[string]]::new()
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Invoke-StagingRequest {
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
            $request.Body = $Body | ConvertTo-Json -Depth 12 -Compress
        }
        $response = Invoke-WebRequest @request
        $json = if ($response.Content) {
            ConvertFrom-Json $response.Content -NoEnumerate
        } else {
            $null
        }
        return [pscustomobject]@{Status=[int]$response.StatusCode; Json=$json}
    }
    catch {
        throw 'H4 Staging smoke transport/JSON failure; response content and credentials were not logged.'
    }
}

function Assert-Status {
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

function Get-CompositeResult {
    param($Json, [string]$Label)
    if ($Json -is [array]) {
        if ($Json.Count -ne 1) { throw "$Label returned an unexpected row count." }
        return $Json[0]
    }
    if ($null -eq $Json) { throw "$Label returned no payload." }
    return $Json
}

function Get-ScopeFixtureCount {
    param([hashtable]$Headers)
    $count = 0
    for ($page = 1; $page -le 20; $page++) {
        $response = Invoke-StagingRequest GET "/auth/v1/admin/users?page=$page&per_page=100" $Headers $null
        Assert-Status $response @(200) 'Fixture inventory'
        $users = @($response.Json.users)
        $count += @($users | Where-Object {
            $_.user_metadata.test_scope -eq $scope
        }).Count
        if ($users.Count -lt 100) { return $count }
    }
    throw 'Fixture inventory was truncated; refusing to claim cleanup.'
}

Push-Location $repoRoot
try {
    $projectsText = (& npx.cmd supabase projects list --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to verify Staging.' }
    $project = @(ConvertFrom-Json $projectsText | Where-Object { $_.ref -eq $stagingRef })
    if ($project.Count -ne 1 -or $project[0].name -cne $ExpectedProjectName -or
        $project[0].status -ne 'ACTIVE_HEALTHY' -or -not $project[0].linked) {
        throw 'Refusing H4 smoke: linked target is not exact healthy Staging.'
    }

    $dryRunText = (& npx.cmd supabase db push --project-ref $stagingRef --dry-run | Out-String)
    if ($LASTEXITCODE -ne 0 -or $dryRunText -notmatch 'up.to.date') {
        throw 'Refusing H4 smoke: Staging migration history is not up to date.'
    }

    $keysText = (& npx.cmd supabase projects api-keys --project-ref $stagingRef --reveal --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to obtain Staging API credentials.' }
    $keys = @(ConvertFrom-Json $keysText)
    $publicKey = @($keys | Where-Object {
        $_.type -eq 'publishable' -or $_.name -eq 'anon' -or $_.id -eq 'anon'
    } | Select-Object -First 1)
    $adminKey = @($keys | Where-Object { $_.type -eq 'secret' } | Select-Object -First 1)
    if ($adminKey.Count -eq 0) {
        $adminKey = @($keys | Where-Object {
            $_.name -eq 'service_role' -or $_.id -eq 'service_role'
        } | Select-Object -First 1)
    }
    if ($publicKey.Count -ne 1 -or $adminKey.Count -ne 1) {
        throw 'Required Staging credentials were not returned.'
    }
    $anonValue = if ($publicKey[0].api_key) { $publicKey[0].api_key } else { $publicKey[0].key }
    $adminValue = if ($adminKey[0].api_key) { $adminKey[0].api_key } else { $adminKey[0].key }
    if (-not $anonValue -or -not $adminValue) { throw 'Unsupported API credential shape.' }
    $agent = 'capy-home-h5-smoke/1.0'
    $anonHeaders = @{apikey=$anonValue; 'User-Agent'=$agent}
    $adminHeaders = @{apikey=$adminValue; Authorization="Bearer $adminValue"; 'User-Agent'=$agent}
    if ((Get-ScopeFixtureCount $adminHeaders) -ne 0) {
        throw 'Pre-existing H4 smoke fixtures require manual audit before a new run.'
    }

    $email = "home-h4-$runId@example.com"
    $password = 'H4!' + [guid]::NewGuid().ToString('N')
    $created = Invoke-StagingRequest POST '/auth/v1/admin/users' $adminHeaders @{
        email = $email
        password = $password
        email_confirm = $true
        user_metadata = @{test_scope=$scope; run_id=$runId}
    }
    Assert-Status $created @(200, 201) 'Fixture creation'
    $fixtureId = [string]$created.Json.id
    if ($fixtureId -notmatch '^[0-9a-f-]{36}$') { throw 'Fixture identity was missing.' }

    $login = Invoke-StagingRequest POST '/auth/v1/token?grant_type=password' $anonHeaders @{
        email=$email; password=$password
    }
    Assert-Status $login @(200) 'Fixture sign-in'
    if ($login.Json.user.id -ne $fixtureId -or -not $login.Json.access_token) {
        throw 'Fixture session mismatch.'
    }
    $ownerHeaders = @{
        apikey = $anonValue
        Authorization = "Bearer $($login.Json.access_token)"
        Prefer = 'return=representation'
        'User-Agent' = $agent
    }

    $emailB = "home-h5-b-$runId@example.com"
    $passwordB = 'H5B!' + [guid]::NewGuid().ToString('N')
    $createdB = Invoke-StagingRequest POST '/auth/v1/admin/users' $adminHeaders @{
        email = $emailB
        password = $passwordB
        email_confirm = $true
        user_metadata = @{test_scope=$scope; run_id=$runId; fixture='b'}
    }
    Assert-Status $createdB @(200, 201) 'Peer fixture creation'
    $fixtureBId = [string]$createdB.Json.id
    if ($fixtureBId -notmatch '^[0-9a-f-]{36}$') { throw 'Peer fixture identity was missing.' }
    $loginB = Invoke-StagingRequest POST '/auth/v1/token?grant_type=password' $anonHeaders @{
        email=$emailB; password=$passwordB
    }
    Assert-Status $loginB @(200) 'Peer fixture sign-in'
    $ownerBHeaders = @{
        apikey = $anonValue
        Authorization = "Bearer $($loginB.Json.access_token)"
        Prefer = 'return=representation'
        'User-Agent' = $agent
    }

    $onboarding = Invoke-StagingRequest POST '/rest/v1/rpc/complete_onboarding' $ownerHeaders @{
        p_display_name='H5 fixture'
        p_username=('h5' + $runId.Substring(0, 14))
        p_age=25
        p_phone=('0' + (Get-Random -Minimum 100000000 -Maximum 1000000000))
        p_account_role='personal'
        p_reminder_time='22:00'
        p_study_end_time='02:00'
        p_daily_target_words=2
        p_native_language_code='vi'
        p_learning_language_code='en'
        p_proficiency_level='beginner'
    }
    Assert-Status $onboarding @(200) 'Fixture onboarding'
    if ($onboarding.Json -ne $true) { throw 'Fixture onboarding did not complete.' }

    $onboardingB = Invoke-StagingRequest POST '/rest/v1/rpc/complete_onboarding' $ownerBHeaders @{
        p_display_name='H5 peer fixture'
        p_username=('h6b' + $runId.Substring(0, 13))
        p_age=25
        p_phone=('0' + (Get-Random -Minimum 100000000 -Maximum 1000000000))
        p_account_role='personal'
        p_reminder_time='22:00'
        p_study_end_time='02:00'
        p_daily_target_words=2
        p_native_language_code='vi'
        p_learning_language_code='en'
        p_proficiency_level='beginner'
    }
    Assert-Status $onboardingB @(200) 'Peer fixture onboarding'
    if ($onboardingB.Json -ne $true) { throw 'Peer fixture onboarding did not complete.' }

    $userBefore = Invoke-StagingRequest GET "/rest/v1/users?id=eq.$fixtureId&select=total_coins,streak_days" $ownerHeaders $null
    Assert-Status $userBefore @(200) 'Reward baseline'
    if (@($userBefore.Json).Count -ne 1) { throw 'Reward baseline row was missing.' }
    $coinsBefore = $userBefore.Json[0].total_coins
    $streakBefore = $userBefore.Json[0].streak_days

    $missionResponse = Invoke-StagingRequest POST '/rest/v1/rpc/ensure_daily_mission' $ownerHeaders @{
        p_detected_time_zone='Asia/Bangkok'
    }
    Assert-Status $missionResponse @(200) 'Daily mission creation'
    $mission = Get-CompositeResult $missionResponse.Json 'Daily mission creation'
    if ($mission.user_id -ne $fixtureId -or -not $mission.mission_date) {
        throw 'Daily mission owner/date mismatch.'
    }
    $checks.Add('isolated_account_and_daily_mission')

    $sessionId = "h5-$runId"
    $resultId = "$sessionId`:completion"
    $completedAt = [DateTime]::UtcNow.ToString('o')
    $payload = [ordered]@{
        p_result_id=$resultId
        p_session_id=$sessionId
        p_mission_date=[string]$mission.mission_date
        p_total_items=2
        p_completed_items=2
        p_source_revision_hash=('a' * 64)
        p_rule_version='h5-smoke-rule-v1'
        p_normalizer_version='h5-smoke-normalizer-v1'
        p_evidence=@{
            items=@(@{id='item-1'}, @{id='item-2'})
            attempts=@(@{verdicts=@(
                @{item_id='item-1'; is_correct=$true},
                @{item_id='item-2'; is_correct=$true}
            )})
        }
        p_completed_at=$completedAt
    }

    $first = Invoke-StagingRequest POST '/rest/v1/rpc/sync_lesson_completion' $ownerHeaders $payload
    Assert-Status $first @(200) 'Initial completion sync'
    $firstReceipt = Get-CompositeResult $first.Json 'Initial completion sync'
    if ($firstReceipt.result_id -ne $resultId -or $firstReceipt.user_id -ne $fixtureId -or
        $firstReceipt.reward_status -ne 'awarded' -or
        $firstReceipt.reward_yuzu -ne 100 -or
        $firstReceipt.weekly_yuzu -ne 100 -or
        $firstReceipt.completion_ordinal -ne 1) {
        throw 'Initial receipt contract mismatch.'
    }

    $second = Invoke-StagingRequest POST '/rest/v1/rpc/sync_lesson_completion' $ownerHeaders $payload
    Assert-Status $second @(200) 'Idempotent completion retry'
    $secondReceipt = Get-CompositeResult $second.Json 'Idempotent completion retry'
    if ($secondReceipt.accepted_at -ne $firstReceipt.accepted_at) {
        throw 'Idempotent retry created a different receipt.'
    }
    $ownerReceipts = Invoke-StagingRequest GET "/rest/v1/lesson_completion_receipts?select=result_id,reward_status&result_id=eq.$resultId" $ownerHeaders $null
    Assert-Status $ownerReceipts @(200) 'Owner receipt read'
    if (@($ownerReceipts.Json).Count -ne 1) { throw 'Idempotent retry did not preserve one receipt.' }
    $checks.Add('receipt_insert_and_idempotent_retry')

    $ledger = Invoke-StagingRequest GET "/rest/v1/yuzu_reward_ledger?select=wallet_yuzu,weekly_yuzu,completion_ordinal&receipt_id=eq.$resultId" $ownerHeaders $null
    Assert-Status $ledger @(200) 'Owner reward ledger read'
    if (@($ledger.Json).Count -ne 1 -or $ledger.Json[0].wallet_yuzu -ne 100 -or
        $ledger.Json[0].weekly_yuzu -ne 100 -or
        $ledger.Json[0].completion_ordinal -ne 1) {
        throw 'First reward ledger contract mismatch.'
    }

    $replaySessionId = "h5-replay-$runId"
    $replayResultId = "$replaySessionId`:completion"
    $replayPayload = [ordered]@{} + $payload
    $replayPayload.p_session_id = $replaySessionId
    $replayPayload.p_result_id = $replayResultId
    $replayPayload.p_completed_at = [DateTime]::UtcNow.ToString('o')
    $replay = Invoke-StagingRequest POST '/rest/v1/rpc/sync_lesson_completion' $ownerHeaders $replayPayload
    Assert-Status $replay @(200) 'Rewarded replay sync'
    $replayReceipt = Get-CompositeResult $replay.Json 'Rewarded replay sync'
    if ($replayReceipt.reward_status -ne 'awarded' -or
        $replayReceipt.reward_yuzu -ne 33 -or
        $replayReceipt.weekly_yuzu -ne 0 -or
        $replayReceipt.completion_ordinal -ne 2) {
        throw 'Rewarded replay settlement mismatch.'
    }
    $checks.Add('first_reward_and_one_third_wallet_only_replay')

    $leaderboard = Invoke-StagingRequest POST '/rest/v1/rpc/list_weekly_yuzu_leaderboard' $ownerHeaders @{}
    Assert-Status $leaderboard @(200) 'Weekly leaderboard read'
    if (@($leaderboard.Json).Count -ne 1 -or
        $leaderboard.Json[0].user_id -ne $fixtureId -or
        $leaderboard.Json[0].weekly_yuzu -ne 100 -or
        $leaderboard.Json[0].rank_position -ne 1) {
        throw 'Weekly leaderboard did not use confirmed first-completion Yuzu.'
    }
    $checks.Add('ledger_backed_weekly_leaderboard')

    $friendRequest = Invoke-StagingRequest POST '/rest/v1/rpc/send_friend_request' $ownerHeaders @{
        p_target_user_id=$fixtureBId
    }
    Assert-Status $friendRequest @(200) 'Synthetic friend request'
    $friendAccept = Invoke-StagingRequest POST '/rest/v1/rpc/respond_friend_request' $ownerBHeaders @{
        p_requester_id=$fixtureId
        p_decision='accept'
    }
    Assert-Status $friendAccept @(200) 'Synthetic friend acceptance'

    $missionBResponse = Invoke-StagingRequest POST '/rest/v1/rpc/ensure_daily_mission' $ownerBHeaders @{
        p_detected_time_zone='Asia/Bangkok'
    }
    Assert-Status $missionBResponse @(200) 'Peer daily mission creation'
    $missionB = Get-CompositeResult $missionBResponse.Json 'Peer daily mission creation'
    $peerSessionId = "h5-peer-$runId"
    $peerPayload = [ordered]@{} + $payload
    $peerPayload.p_session_id = $peerSessionId
    $peerPayload.p_result_id = "$peerSessionId`:completion"
    $peerPayload.p_mission_date = [string]$missionB.mission_date
    $peerPayload.p_completed_at = [DateTime]::UtcNow.ToString('o')
    $peerCompletion = Invoke-StagingRequest POST '/rest/v1/rpc/sync_lesson_completion' $ownerBHeaders $peerPayload
    Assert-Status $peerCompletion @(200) 'Peer completion sync'

    $leaderboardA = Invoke-StagingRequest POST '/rest/v1/rpc/list_weekly_yuzu_leaderboard' $ownerHeaders @{}
    $leaderboardB = Invoke-StagingRequest POST '/rest/v1/rpc/list_weekly_yuzu_leaderboard' $ownerBHeaders @{}
    Assert-Status $leaderboardA @(200) 'Owner two-peer leaderboard'
    Assert-Status $leaderboardB @(200) 'Peer two-peer leaderboard'
    $rankA = @($leaderboardA.Json | ForEach-Object { "$($_.user_id):$($_.weekly_yuzu):$($_.rank_position)" })
    $rankB = @($leaderboardB.Json | ForEach-Object { "$($_.user_id):$($_.weekly_yuzu):$($_.rank_position)" })
    if ($rankA.Count -ne 2 -or $rankB.Count -ne 2 -or
        ($rankA -join '|') -cne ($rankB -join '|') -or
        @($leaderboardA.Json | Where-Object { $_.weekly_yuzu -ne 100 -or $_.rank_position -ne 1 }).Count -ne 0) {
        throw 'Two accepted peers did not receive the same weekly ordering.'
    }
    $checks.Add('two_accounts_receive_identical_confirmed_ranks')

    $conflictPayload = [ordered]@{} + $payload
    $conflictPayload.p_normalizer_version = 'h5-smoke-normalizer-conflict'
    $conflict = Invoke-StagingRequest POST '/rest/v1/rpc/sync_lesson_completion' $ownerHeaders $conflictPayload
    Assert-Status $conflict @(409) 'Changed-payload conflict'
    if ($conflict.Json.code -ne '23505') { throw 'Changed-payload conflict returned the wrong SQLSTATE.' }
    $checks.Add('changed_payload_rejected')

    $anonRead = Invoke-StagingRequest GET '/rest/v1/lesson_completion_receipts?select=result_id' $anonHeaders $null
    Assert-Status $anonRead @(401, 403) 'Anonymous receipt rejection'
    $directWrite = Invoke-StagingRequest POST '/rest/v1/lesson_completion_receipts' $ownerHeaders @{
        result_id='forbidden'
    }
    Assert-Status $directWrite @(401, 403, 405) 'Direct receipt write rejection'
    $checks.Add('authenticated_rpc_only_and_anon_rejected')

    $userAfter = Invoke-StagingRequest GET "/rest/v1/users?id=eq.$fixtureId&select=total_coins,streak_days" $ownerHeaders $null
    Assert-Status $userAfter @(200) 'Reward settlement read'
    if ($userAfter.Json[0].total_coins -ne ($coinsBefore + 133) -or
        $userAfter.Json[0].streak_days -ne ($streakBefore + 1)) {
        throw 'H5 wallet or streak settlement mismatch.'
    }
    $checks.Add('wallet_and_streak_settled_once')
}
finally {
    try {
        if ($fixtureId -and $adminHeaders) {
            $fixture = Invoke-StagingRequest GET "/auth/v1/admin/users/$fixtureId" $adminHeaders $null
            Assert-Status $fixture @(200) 'Cleanup identity read'
            if ($fixture.Json.user_metadata.test_scope -ne $scope -or
                $fixture.Json.user_metadata.run_id -ne $runId) {
                throw 'Refusing cleanup: fixture identity does not match this run.'
            }
            Assert-Status (
                Invoke-StagingRequest DELETE "/auth/v1/admin/users/$fixtureId" $adminHeaders $null
            ) @(200, 204) 'Fixture deletion'
            $remaining = Invoke-StagingRequest GET "/rest/v1/lesson_completion_receipts?user_id=eq.$fixtureId&select=result_id" $adminHeaders $null
            Assert-Status $remaining @(200) 'Receipt cascade verification'
            if (@($remaining.Json).Count -ne 0) { throw 'Fixture receipt cleanup failed.' }
            $remainingLedger = Invoke-StagingRequest GET "/rest/v1/yuzu_reward_ledger?user_id=eq.$fixtureId&select=id" $adminHeaders $null
            Assert-Status $remainingLedger @(200) 'Reward ledger cascade verification'
            if (@($remainingLedger.Json).Count -ne 0) { throw 'Fixture reward ledger cleanup failed.' }
            if ($fixtureBId) {
                $fixtureB = Invoke-StagingRequest GET "/auth/v1/admin/users/$fixtureBId" $adminHeaders $null
                Assert-Status $fixtureB @(200) 'Peer cleanup identity read'
                if ($fixtureB.Json.user_metadata.test_scope -ne $scope -or
                    $fixtureB.Json.user_metadata.run_id -ne $runId) {
                    throw 'Refusing cleanup: peer fixture identity does not match this run.'
                }
                Assert-Status (
                    Invoke-StagingRequest DELETE "/auth/v1/admin/users/$fixtureBId" $adminHeaders $null
                ) @(200, 204) 'Peer fixture deletion'
            }
            if ((Get-ScopeFixtureCount $adminHeaders) -ne 0) {
                throw 'H5 Auth fixture cleanup failed.'
            }
            $checks.Add('fixture_and_receipt_cleanup')
        }
    }
    finally {
        $keysText=$null; $keys=$null; $anonValue=$null; $adminValue=$null
        $anonHeaders=$null; $adminHeaders=$null; $ownerHeaders=$null
        Pop-Location
    }
}

[pscustomobject]@{
    status='VERIFIED'
    project_ref=$stagingRef
    checks=$checks.ToArray()
    fixture_count_remaining=0
    reward_writes=3
} | ConvertTo-Json -Depth 4
