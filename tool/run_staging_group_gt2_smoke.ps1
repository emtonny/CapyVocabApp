#requires -Version 7.0
# Five isolated fixture accounts; never modifies demo users or Production.
param(
    [string]$ExpectedProjectName = "emtonny's Project",
    [string]$PostgresBin = 'C:\Program Files\PostgreSQL\18\bin',
    [switch]$IncludeGt3Chat,
    [switch]$IncludeGt4Management,
    [switch]$IncludeGt5Assignments
)

$ErrorActionPreference = 'Stop'
$stagingRef = 'nxteaznowkfennxpqjmt'
$baseUrl = "https://$stagingRef.supabase.co"
$runId = [guid]::NewGuid().ToString('N')
$scope = if ($IncludeGt5Assignments) {
    'group_gt5_assignments_smoke'
} elseif ($IncludeGt4Management) {
    'group_gt4_management_smoke'
} elseif ($IncludeGt3Chat) {
    'group_gt3_learning_group_chat_smoke'
} else {
    'group_gt2_learning_group_smoke'
}
$label = if ($IncludeGt5Assignments) {
    'GT5'
} elseif ($IncludeGt4Management) {
    'GT4'
} elseif ($IncludeGt3Chat) {
    'GT3'
} else {
    'GT2'
}
$fixtureIds = [Collections.Generic.List[string]]::new()
$checks = [Collections.Generic.List[string]]::new()
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$groupId = $null
$conversationId = $null
$messageId = $null
$lessonResultId = $null
$lessonMissionDate = $null
$translationMode = if ($IncludeGt3Chat) { 'pending' } else { 'not_requested' }
$primaryFailure = $null
$cleanupErrors = [Collections.Generic.List[string]]::new()

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
        throw "$label Staging smoke transport/JSON failure; credentials and response body were not logged."
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

function Empty {
    param($Response, [string]$Label)
    Status $Response @(200) $Label
    if (@($Response.Json).Count -ne 0) {
        throw "$Label returned protected rows."
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
    $prefix = $label.ToLowerInvariant()
    $email = "$prefix-$Label-$runId@example.com"
    $password = "$label!" + [guid]::NewGuid().ToString('N')
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
        Email = $email
        Password = $password
        Headers = @{
            apikey = $AnonHeaders.apikey
            Authorization = "Bearer $($login.Json.access_token)"
            Prefer = 'return=representation'
            'User-Agent' = "capy-group-$($label.ToLowerInvariant())-smoke/1.0"
        }
    }
}

function Complete-Onboarding {
    param($Fixture, [string]$Role, [string]$Username)
    $response = Request POST '/rest/v1/rpc/complete_onboarding' `
        $Fixture.Headers @{
            p_display_name = "GT2 $Role fixture"
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

function Verify-Teacher {
    param($Fixture, [hashtable]$AdminHeaders)
    $response = Request POST '/rest/v1/rpc/set_teacher_verification' `
        $AdminHeaders @{
            p_teacher_user_id = $Fixture.Id
            p_status = 'verified'
            p_reason_code = 'gt2_smoke'
        }
    Status $response @(200) 'Service teacher verification'
    if ($response.Json -ne $true) { throw 'Teacher verification returned false.' }
}

function Get-PostgresEnvironment {
    param([string]$Script)
    $required = @('PGHOST', 'PGPORT', 'PGUSER', 'PGPASSWORD', 'PGDATABASE')
    $result = @{}
    foreach ($match in [regex]::Matches(
        $Script, '(?m)^\s*(?:export\s+)?(PG[A-Z]+)=(.*)$'
    )) {
        $name = $match.Groups[1].Value
        if ($name -notin $required) { continue }
        $quoted = $match.Groups[2].Value.Trim()
        if ($result.ContainsKey($name) -or
            $quoted -notmatch '^"([^"\\$`]+)"$') {
            throw 'Unsupported PostgreSQL credential quoting; refusing shell evaluation.'
        }
        $result[$name] = $Matches[1]
    }
    if ($result.Count -ne $required.Count) {
        throw 'Incomplete PostgreSQL environment in CLI dry-run.'
    }
    return $result
}

function New-Gt5DailyMissionFixture {
    param([string]$StudentId)
    if ($StudentId -notmatch '^[0-9a-f-]{36}$') {
        throw 'Refusing GT5 mission fixture with invalid student identifier.'
    }
    $psql = Join-Path $PostgresBin 'psql.exe'
    if (-not (Test-Path -LiteralPath $psql)) {
        throw 'PostgreSQL psql is required to create the GT5 mission fixture.'
    }
    $dumpScript = (& npx.cmd supabase db dump --project-ref $stagingRef `
        --dry-run | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to obtain bounded Staging fixture connection.'
    }
    $postgresEnvironment = Get-PostgresEnvironment $dumpScript
    $previous = @{}
    try {
        foreach ($name in $postgresEnvironment.Keys) {
            $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
            [Environment]::SetEnvironmentVariable(
                $name, $postgresEnvironment[$name], 'Process'
            )
        }
        $previous.PGSSLMODE = [Environment]::GetEnvironmentVariable(
            'PGSSLMODE', 'Process'
        )
        [Environment]::SetEnvironmentVariable('PGSSLMODE', 'require', 'Process')
        $sql = @'
SET ROLE postgres;
INSERT INTO public.daily_missions (
    user_id, mission_date, time_zone, target_words,
    starts_at, ends_at, next_day_ends_at
) VALUES (
    '__STUDENT_ID__'::UUID, CURRENT_DATE, 'Asia/Bangkok', 2,
    NOW() - INTERVAL '1 hour', NOW() + INTERVAL '1 hour',
    NOW() + INTERVAL '25 hours'
);
SELECT CURRENT_DATE;
'@.Replace('__STUDENT_ID__', $StudentId)
        $output = (& $psql -X -q -A -t -v ON_ERROR_STOP=1 `
            -c $sql 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or $output -notmatch '^\d{4}-\d{2}-\d{2}$') {
            throw 'GT5 daily mission fixture creation failed.'
        }
        return $output
    }
    finally {
        foreach ($name in $previous.Keys) {
            [Environment]::SetEnvironmentVariable(
                $name, $previous[$name], 'Process'
            )
        }
        $dumpScript = $null
        $postgresEnvironment = $null
    }
}

function Remove-AndAssertDatabaseFixture {
    param(
        [string]$FixtureGroupId,
        [string]$OwnerId,
        [string]$FixtureConversationId,
        [string]$FixtureMessageId,
        [string]$FixtureLessonResultId,
        [string]$StudentId,
        [string]$MissionDate
    )
    if (-not $FixtureGroupId) { return }
    if ($FixtureGroupId -notmatch '^[0-9a-f-]{36}$' -or
        $OwnerId -notmatch '^[0-9a-f-]{36}$' -or
        $StudentId -and $StudentId -notmatch '^[0-9a-f-]{36}$' -or
        $MissionDate -and $MissionDate -notmatch '^\d{4}-\d{2}-\d{2}$') {
        throw "Refusing $label database cleanup with invalid fixture identifiers."
    }
    $psql = Join-Path $PostgresBin 'psql.exe'
    if (-not (Test-Path -LiteralPath $psql)) {
        throw 'PostgreSQL psql is required to verify GT2 cleanup.'
    }
    $dumpScript = (& npx.cmd supabase db dump --project-ref $stagingRef `
        --dry-run | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to obtain bounded Staging cleanup connection.'
    }
    $postgresEnvironment = Get-PostgresEnvironment $dumpScript
    $previous = @{}
    try {
        foreach ($name in $postgresEnvironment.Keys) {
            $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
            [Environment]::SetEnvironmentVariable(
                $name, $postgresEnvironment[$name], 'Process'
            )
        }
        $previous.PGSSLMODE = [Environment]::GetEnvironmentVariable(
            'PGSSLMODE', 'Process'
        )
        [Environment]::SetEnvironmentVariable('PGSSLMODE', 'require', 'Process')
        $sql = @'
SET ROLE postgres;
DELETE FROM public.lesson_completion_receipts
WHERE result_id = NULLIF('__LESSON_RESULT_ID__', '')
  AND user_id = NULLIF('__STUDENT_ID__', '')::UUID;
DELETE FROM public.daily_missions
WHERE user_id = NULLIF('__STUDENT_ID__', '')::UUID
  AND mission_date = NULLIF('__MISSION_DATE__', '')::DATE;
DELETE FROM public.learning_groups
WHERE id = '__GROUP_ID__'::UUID
  AND owner_teacher_id = '__OWNER_ID__'::UUID
RETURNING id;
SELECT
    (SELECT COUNT(*) FROM public.learning_groups WHERE id = '__GROUP_ID__'::UUID)
  + (SELECT COUNT(*) FROM public.learning_group_members WHERE group_id = '__GROUP_ID__'::UUID)
  + (SELECT COUNT(*) FROM public.learning_group_invites WHERE group_id = '__GROUP_ID__'::UUID)
  + (SELECT COUNT(*) FROM public.learning_group_announcements WHERE group_id = '__GROUP_ID__'::UUID)
  + (SELECT COUNT(*) FROM private.learning_group_moderation_events WHERE group_id = '__GROUP_ID__'::UUID)
  + (SELECT COUNT(*) FROM public.chat_conversations WHERE id = NULLIF('__CONVERSATION_ID__','')::UUID)
  + (SELECT COUNT(*) FROM public.chat_members WHERE conversation_id = NULLIF('__CONVERSATION_ID__','')::UUID)
  + (SELECT COUNT(*) FROM public.chat_operational_messages WHERE id = NULLIF('__MESSAGE_ID__','')::UUID)
  + (SELECT COUNT(*) FROM public.chat_translations WHERE message_id = NULLIF('__MESSAGE_ID__','')::UUID)
  + (SELECT COUNT(*) FROM public.chat_corrections WHERE message_id = NULLIF('__MESSAGE_ID__','')::UUID)
  + (SELECT COUNT(*) FROM private.learning_group_system_tasks WHERE group_id = '__GROUP_ID__'::UUID)
  + (SELECT COUNT(*) FROM private.learning_group_vocabulary_shares WHERE group_id = '__GROUP_ID__'::UUID)
  + (SELECT COUNT(*) FROM private.learning_group_vocabulary_progress WHERE group_id = '__GROUP_ID__'::UUID)
  + (SELECT COUNT(*) FROM public.lesson_completion_receipts WHERE result_id = NULLIF('__LESSON_RESULT_ID__', ''))
  + (SELECT COUNT(*) FROM public.daily_missions WHERE user_id = NULLIF('__STUDENT_ID__', '')::UUID AND mission_date = NULLIF('__MISSION_DATE__', '')::DATE);
'@
        $sql = $sql.Replace('__GROUP_ID__', $FixtureGroupId).
            Replace('__OWNER_ID__', $OwnerId).
            Replace('__CONVERSATION_ID__', [string]$FixtureConversationId).
            Replace('__MESSAGE_ID__', [string]$FixtureMessageId).
            Replace('__LESSON_RESULT_ID__', [string]$FixtureLessonResultId).
            Replace('__STUDENT_ID__', [string]$StudentId).
            Replace('__MISSION_DATE__', [string]$MissionDate)
        $output = (& $psql -X -q -A -t -v ON_ERROR_STOP=1 `
            -c $sql 2>&1 | Out-String).Trim()
        $lines = @($output -split "`r?`n" | Where-Object { $_ -ne '' })
        if ($LASTEXITCODE -ne 0 -or $lines.Count -ne 2 -or
            $lines[0] -ne $FixtureGroupId -or $lines[1] -ne '0') {
            throw "$label database fixture cleanup did not reach zero."
        }
    }
    finally {
        foreach ($name in $previous.Keys) {
            [Environment]::SetEnvironmentVariable(
                $name, $previous[$name], 'Process'
            )
        }
        $dumpScript = $null
        $postgresEnvironment = $null
    }
}

Push-Location $repoRoot
try {
    $projectsText = (& npx.cmd supabase projects list --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to verify Staging.' }
    $projects = @(ConvertFrom-Json $projectsText)
    $project = @($projects | Where-Object { $_.ref -eq $stagingRef })
    if ($project.Count -ne 1 -or $project[0].name -cne $ExpectedProjectName -or
        $project[0].status -ne 'ACTIVE_HEALTHY' -or -not $project[0].linked -or
        @($projects | Where-Object { $_.status -eq 'ACTIVE_HEALTHY' }).Count -gt 2) {
        throw 'Refusing GT2 smoke: linked target is not exact healthy Staging.'
    }

    $dryRunText = (& npx.cmd supabase db push --project-ref $stagingRef `
        --dry-run | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'GT2 post-apply dry-run failed.' }
    $dryRun = ConvertFrom-Json $dryRunText
    if ($dryRun.upToDate -ne $true) {
        throw 'Refusing GT2 smoke: Staging migration history is not up to date.'
    }
    $historyText = (& npx.cmd supabase migration list --project-ref $stagingRef |
        Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to verify GT2 migration history.' }
    $history = ConvertFrom-Json $historyText
    $gt2 = @($history.migrations | Where-Object {
        $_.local -eq '20261013140000' -and $_.remote -eq '20261013140000'
    })
    if ($gt2.Count -ne 1) {
        throw 'GT2 migration is not applied exactly once on Staging.'
    }
    if ($IncludeGt3Chat) {
        $gt3 = @($history.migrations | Where-Object {
            $_.local -eq '20261017120000' -and $_.remote -eq '20261017120000'
        })
        if ($gt3.Count -ne 1) {
            throw 'GT3 migration is not applied exactly once on Staging.'
        }
    }
    if ($IncludeGt4Management) {
        $gt4 = @($history.migrations | Where-Object {
            $_.local -eq '20261020120000' -and $_.remote -eq '20261020120000'
        })
        if ($gt4.Count -ne 1) {
            throw 'GT4 migration is not applied exactly once on Staging.'
        }
    }
    if ($IncludeGt5Assignments) {
        $gt5 = @($history.migrations | Where-Object {
            $_.local -eq '20261020130000' -and $_.remote -eq '20261020130000'
        })
        if ($gt5.Count -ne 1) {
            throw 'GT5 migration is not applied exactly once on Staging.'
        }
    }

    $keysText = (& npx.cmd supabase projects api-keys `
        --project-ref $stagingRef --reveal --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to obtain Staging API credentials.' }
    $keys = @(ConvertFrom-Json $keysText)
    $publicKey = @($keys | Where-Object {
        $_.type -eq 'publishable' -or $_.name -eq 'anon' -or $_.id -eq 'anon'
    } | Select-Object -First 1)
    $adminKey = @($keys | Where-Object { $_.type -eq 'secret' } |
        Select-Object -First 1)
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
    $agent = "capy-group-$($label.ToLowerInvariant())-smoke/1.0"
    $anonHeaders = @{apikey=$anonValue; 'User-Agent'=$agent}
    $adminHeaders = @{
        apikey = $adminValue
        Authorization = "Bearer $adminValue"
        Prefer = 'return=representation'
        'User-Agent' = $agent
    }
    if ((Get-ScopeFixtureCount $adminHeaders) -ne 0) {
        throw 'Pre-existing GT2 smoke fixtures require manual audit.'
    }

    $teacherA = New-Fixture 'teacher-a' $adminHeaders $anonHeaders
    $teacherB = New-Fixture 'teacher-b' $adminHeaders $anonHeaders
    $studentA = New-Fixture 'student-a' $adminHeaders $anonHeaders
    $studentB = New-Fixture 'student-b' $adminHeaders $anonHeaders
    $studentC = New-Fixture 'student-c' $adminHeaders $anonHeaders
    Complete-Onboarding $teacherA 'teacher' ('gt2ta' + $runId.Substring(0, 12))
    Complete-Onboarding $teacherB 'teacher' ('gt2tb' + $runId.Substring(0, 12))
    Complete-Onboarding $studentA 'personal' ('gt2sa' + $runId.Substring(0, 12))
    Complete-Onboarding $studentB 'personal' ('gt2sb' + $runId.Substring(0, 12))
    Complete-Onboarding $studentC 'personal' ('gt2sc' + $runId.Substring(0, 12))
    Verify-Teacher $teacherA $adminHeaders
    Verify-Teacher $teacherB $adminHeaders

    $teacherCapabilities = Request POST `
        '/rest/v1/rpc/get_my_learning_group_capabilities' `
        $teacherA.Headers @{}
    Status $teacherCapabilities @(200) 'Teacher group capabilities'
    if (@($teacherCapabilities.Json).Count -ne 1 -or
        $teacherCapabilities.Json[0].can_manage_groups -ne $true) {
        throw 'Verified teacher did not receive group capability.'
    }
    $studentCapabilities = Request POST `
        '/rest/v1/rpc/get_my_learning_group_capabilities' `
        $studentA.Headers @{}
    Status $studentCapabilities @(200) 'Student group capabilities'
    if (@($studentCapabilities.Json).Count -ne 1 -or
        $studentCapabilities.Json[0].can_manage_groups -ne $false) {
        throw 'Personal account received group management capability.'
    }
    $checks.Add('verified_teacher_capability_and_student_fail_closed')

    $createRequest = [guid]::NewGuid().ToString()
    $created = Request POST '/rest/v1/rpc/create_learning_group' `
        $teacherA.Headers @{
            p_title = 'GT2 exact Staging class'
            p_description = 'Synthetic cleanup-bound fixture'
            p_request_id = $createRequest
        }
    Status $created @(200) 'Group creation'
    $groupId = [string]$created.Json
    if ($groupId -notmatch '^[0-9a-f-]{36}$') {
        throw 'Group creation returned no UUID.'
    }
    $retry = Request POST '/rest/v1/rpc/create_learning_group' `
        $teacherA.Headers @{
            p_title = 'Ignored retry title'
            p_description = ''
            p_request_id = $createRequest
        }
    Status $retry @(200) 'Group creation retry'
    if ([string]$retry.Json -ne $groupId) {
        throw 'Group creation request id was not idempotent.'
    }
    $checks.Add('group_create_and_request_id_idempotency')

    $crossOwner = Request POST '/rest/v1/rpc/update_learning_group' `
        $teacherB.Headers @{
            p_group_id = $groupId
            p_title = 'Forbidden cross-owner update'
            p_description = ''
            p_request_id = [guid]::NewGuid().ToString()
        }
    Status $crossOwner @(400, 401, 403) 'Cross-owner group update rejection'
    $directInvite = Request GET `
        '/rest/v1/learning_group_invites?select=token_hash' `
        $studentA.Headers $null
    Status $directInvite @(401, 403, 404) 'Direct invite hash read rejection'
    $checks.Add('cross_owner_and_invite_hash_access_rejected')

    $rotated = Request POST '/rest/v1/rpc/rotate_learning_group_invite' `
        $teacherA.Headers @{
            p_group_id = $groupId
            p_expires_at = [DateTime]::UtcNow.AddDays(7).ToString('o')
            p_request_id = [guid]::NewGuid().ToString()
        }
    Status $rotated @(200) 'Invite rotation'
    $invite = [string]$rotated.Json
    if ($invite -notmatch '^[0-9a-f]{64}$') {
        throw 'Invite rotation did not return a 256-bit hex secret.'
    }
    if ($IncludeGt4Management) {
        $inviteStatus = Request POST `
            '/rest/v1/rpc/get_learning_group_invite_status' `
            $teacherA.Headers @{p_group_id=$groupId}
        Status $inviteStatus @(200) 'GT4 owner invite metadata'
        if (@($inviteStatus.Json).Count -ne 1 -or
            $inviteStatus.Json[0].has_active_invite -ne $true -or
            -not $inviteStatus.Json[0].expires_at -or
            $inviteStatus.Json[0].PSObject.Properties.Name -contains 'token_hash' -or
            $inviteStatus.Json[0].PSObject.Properties.Name -contains 'token') {
            throw 'GT4 invite metadata projection is invalid or discloses a secret.'
        }
        Status (Request POST `
            '/rest/v1/rpc/get_learning_group_invite_status' `
            $teacherB.Headers @{p_group_id=$groupId}) @(400, 401, 403) `
            'GT4 cross-owner invite metadata rejection'
        $checks.Add('owner_only_invite_metadata_without_secret')
    }
    $wrongJoin = Request POST '/rest/v1/rpc/request_learning_group_join' `
        $studentC.Headers @{
            p_invite_token = ('f' * 64)
            p_request_id = [guid]::NewGuid().ToString()
        }
    Status $wrongJoin @(200) 'Wrong invite rejection'
    if ($null -ne $wrongJoin.Json) {
        throw 'Wrong invite disclosed a group result.'
    }
    foreach ($student in @($studentA, $studentB)) {
        $join = Request POST '/rest/v1/rpc/request_learning_group_join' `
            $student.Headers @{
                p_invite_token = $invite
                p_request_id = [guid]::NewGuid().ToString()
            }
        Status $join @(200) 'Pending membership request'
        if ([string]$join.Json -ne $groupId) {
            throw 'Valid invite did not return the expected group.'
        }
    }
    $checks.Add('invite_secret_wrong_token_and_pending_join_contract')

    $announcementRequest = [guid]::NewGuid().ToString()
    $announcement = Request POST `
        '/rest/v1/rpc/create_learning_group_announcement' `
        $teacherA.Headers @{
            p_group_id = $groupId
            p_body = 'GT2 pending visibility fixture'
            p_request_id = $announcementRequest
        }
    Status $announcement @(200) 'Announcement creation'
    $announcementId = [string]$announcement.Json
    if ($announcementId -notmatch '^[0-9a-f-]{36}$') {
        throw 'Announcement creation returned no UUID.'
    }
    $pendingAnnouncements = Request POST `
        '/rest/v1/rpc/list_learning_group_announcements' `
        $studentA.Headers @{p_group_id=$groupId}
    Status $pendingAnnouncements @(400, 401, 403) `
        'Pending announcement access rejection'

    $memberList = Request POST '/rest/v1/rpc/list_learning_group_members' `
        $teacherA.Headers @{p_group_id=$groupId}
    Status $memberList @(200) 'Owner member list'
    if (@($memberList.Json).Count -ne 3) {
        throw 'Owner did not receive owner plus two pending students.'
    }
    $approve = Request POST '/rest/v1/rpc/respond_learning_group_join' `
        $teacherA.Headers @{
            p_group_id = $groupId
            p_student_user_id = $studentA.Id
            p_decision = 'approve'
            p_request_id = [guid]::NewGuid().ToString()
            p_reason_code = $null
        }
    Status $approve @(200) 'Student approval'
    if ($approve.Json -ne 'active') { throw 'Approval did not return active.' }
    $reject = Request POST '/rest/v1/rpc/respond_learning_group_join' `
        $teacherA.Headers @{
            p_group_id = $groupId
            p_student_user_id = $studentB.Id
            p_decision = 'reject'
            p_request_id = [guid]::NewGuid().ToString()
            p_reason_code = 'gt2_smoke'
        }
    Status $reject @(200) 'Student rejection'
    if ($reject.Json -ne 'rejected') { throw 'Rejection returned wrong status.' }
    $activeAnnouncements = Request POST `
        '/rest/v1/rpc/list_learning_group_announcements' `
        $studentA.Headers @{p_group_id=$groupId}
    Status $activeAnnouncements @(200) 'Active announcement list'
    if (@($activeAnnouncements.Json).Count -ne 1) {
        throw 'Active student did not read the teacher announcement.'
    }
    $checks.Add('pending_visibility_approve_reject_and_active_rls')

    if ($IncludeGt5Assignments) {
        $taskRequestId = [guid]::NewGuid().ToString()
        $taskDueAt = [DateTime]::UtcNow.AddDays(7).ToString('o')
        $taskBody = @{
            p_group_id = $groupId
            p_title = 'GT5 learn two new words'
            p_target_word_count = 2
            p_due_at = $taskDueAt
            p_request_id = $taskRequestId
        }
        $taskCreated = Request POST `
            '/rest/v1/rpc/create_learning_group_system_task' `
            $teacherA.Headers $taskBody
        Status $taskCreated @(200) 'GT5 task creation'
        $taskId = [string]$taskCreated.Json
        if ($taskId -notmatch '^[0-9a-f-]{36}$') {
            throw 'GT5 task creation returned no UUID.'
        }
        $taskRetry = Request POST `
            '/rest/v1/rpc/create_learning_group_system_task' `
            $teacherA.Headers $taskBody
        Status $taskRetry @(200) 'GT5 task idempotent retry'
        if ([string]$taskRetry.Json -ne $taskId) {
            throw 'GT5 task request id was not idempotent.'
        }
        Status (Request POST `
            '/rest/v1/rpc/create_learning_group_system_task' `
            $studentA.Headers @{
                p_group_id = $groupId
                p_title = 'Forbidden student task'
                p_target_word_count = 2
                p_due_at = $taskDueAt
                p_request_id = [guid]::NewGuid().ToString()
            }) @(400, 401, 403) 'GT5 student task creation rejection'
        $studentTasks = Request POST `
            '/rest/v1/rpc/list_learning_group_system_tasks' `
            $studentA.Headers @{p_group_id=$groupId}
        Status $studentTasks @(200) 'GT5 student task list'
        $studentTask = @($studentTasks.Json | Where-Object { $_.task_id -eq $taskId })
        if ($studentTask.Count -ne 1 -or
            $studentTask[0].progress_status -ne 'sharing_off' -or
            $studentTask[0].sharing_enabled -ne $false) {
            throw 'GT5 student task did not start with sharing off.'
        }
        $checks.Add('system_task_idempotency_student_read_and_mutation_denial')

        $sharing = Request POST `
            '/rest/v1/rpc/set_learning_group_vocabulary_sharing' `
            $studentA.Headers @{p_group_id=$groupId; p_enabled=$true}
        Status $sharing @(200) 'GT5 enable vocabulary sharing'
        if ($sharing.Json -ne $true) { throw 'GT5 sharing did not enable.' }
        $sharingState = Request POST `
            '/rest/v1/rpc/get_my_learning_group_vocabulary_sharing' `
            $studentA.Headers @{p_group_id=$groupId}
        Status $sharingState @(200) 'GT5 vocabulary sharing state'
        if ($sharingState.Json -ne $true) { throw 'GT5 sharing state was not true.' }

        $lessonMissionDate = New-Gt5DailyMissionFixture $studentA.Id
        $lessonSessionId = "gt5-$runId"
        $lessonResultId = "$lessonSessionId`:completion"
        $lessonCompletedAt = [DateTime]::UtcNow.ToString('o')
        $lessonEvidence = @{
            items = @(
                @{id='gt5-item-apple'; word='apple'},
                @{id='gt5-item-book'; word='book'}
            )
            attempts = @(@{
                id = 'gt5-attempt-1'
                verdicts = @(
                    @{item_id='gt5-item-apple'; is_correct=$true},
                    @{item_id='gt5-item-book'; is_correct=$true}
                )
            })
        }
        $receipt = Request POST '/rest/v1/rpc/sync_lesson_completion' `
            $studentA.Headers @{
                p_result_id = $lessonResultId
                p_session_id = $lessonSessionId
                p_mission_date = $lessonMissionDate
                p_total_items = 2
                p_completed_items = 2
                p_source_revision_hash = ('b' * 64)
                p_rule_version = 'gt5-smoke-v1'
                p_normalizer_version = 'gt5-smoke-v1'
                p_evidence = $lessonEvidence
                p_completed_at = $lessonCompletedAt
            }
        Status $receipt @(200) 'GT5 accepted lesson receipt'
        if ($receipt.Json.result_id -ne $lessonResultId) {
            throw 'GT5 lesson receipt did not return the expected result.'
        }

        $overview = Request POST `
            '/rest/v1/rpc/list_learning_group_learning_overview' `
            $teacherA.Headers @{p_group_id=$groupId}
        Status $overview @(200) 'GT5 owner learning overview'
        $studentOverview = @($overview.Json | Where-Object {
            $_.student_user_id -eq $studentA.Id
        })
        if ($studentOverview.Count -ne 1 -or
            $studentOverview[0].sharing_enabled -ne $true -or
            $studentOverview[0].total_learned_word_count -ne 2 -or
            $studentOverview[0].completed_task_count -ne 1) {
            throw 'GT5 owner overview did not derive accepted lesson progress.'
        }
        $vocabulary = Request POST `
            '/rest/v1/rpc/list_learning_group_student_vocabulary' `
            $teacherA.Headers @{
                p_group_id = $groupId
                p_student_user_id = $studentA.Id
                p_limit = 200
            }
        Status $vocabulary @(200) 'GT5 owner text-only vocabulary'
        if (@($vocabulary.Json).Count -ne 2 -or
            @($vocabulary.Json | Where-Object {
                $_.PSObject.Properties.Name -contains 'source_receipt_id' -or
                $_.PSObject.Properties.Name -contains 'source_item_id' -or
                $_.PSObject.Properties.Name -contains 'photo_note_id' -or
                $_.PSObject.Properties.Name -contains 'media_asset_id' -or
                $_.PSObject.Properties.Name -contains 'image_path' -or
                $_.PSObject.Properties.Name -contains 'raw_response'
            }).Count -ne 0) {
            throw 'GT5 vocabulary projection leaked source or image metadata.'
        }
        Status (Request POST `
            '/rest/v1/rpc/list_learning_group_learning_overview' `
            $studentA.Headers @{p_group_id=$groupId}) @(400, 401, 403) `
            'GT5 student overview rejection'
        Status (Request POST `
            '/rest/v1/rpc/list_learning_group_student_vocabulary' `
            $studentA.Headers @{
                p_group_id=$groupId
                p_student_user_id=$studentA.Id
                p_limit=200
            }) @(400, 401, 403) 'GT5 student vocabulary projection rejection'
        $checks.Add('accepted_receipt_owner_aggregate_and_text_only_projection')

        $sharingOff = Request POST `
            '/rest/v1/rpc/set_learning_group_vocabulary_sharing' `
            $studentA.Headers @{p_group_id=$groupId; p_enabled=$false}
        Status $sharingOff @(200) 'GT5 revoke vocabulary sharing'
        if ($sharingOff.Json -ne $false) { throw 'GT5 sharing did not revoke.' }
        $revokedOverview = Request POST `
            '/rest/v1/rpc/list_learning_group_learning_overview' `
            $teacherA.Headers @{p_group_id=$groupId}
        Status $revokedOverview @(200) 'GT5 revoked learning overview'
        $revokedStudent = @($revokedOverview.Json | Where-Object {
            $_.student_user_id -eq $studentA.Id
        })
        if ($revokedStudent.Count -ne 1 -or
            $revokedStudent[0].sharing_enabled -ne $false -or
            $revokedStudent[0].total_learned_word_count -ne 0) {
            throw 'GT5 revocation did not purge teacher-visible projection.'
        }
        $closedTask = Request POST `
            '/rest/v1/rpc/close_learning_group_system_task' `
            $teacherA.Headers @{
                p_group_id=$groupId
                p_task_id=$taskId
                p_request_id=[guid]::NewGuid().ToString()
            }
        Status $closedTask @(200) 'GT5 close system task'
        if ($closedTask.Json -ne $true) { throw 'GT5 task close returned false.' }
        $taskAudit = Request POST `
            '/rest/v1/rpc/list_learning_group_moderation_events' `
            $teacherA.Headers @{p_group_id=$groupId; p_limit=100}
        Status $taskAudit @(200) 'GT5 task audit'
        $taskAuditActions = @($taskAudit.Json | ForEach-Object { [string]$_.action })
        if (@($taskAuditActions | Where-Object { $_ -eq 'system_task_created' }).Count -ne 1 -or
            @($taskAuditActions | Where-Object { $_ -eq 'system_task_closed' }).Count -ne 1) {
            throw 'GT5 task audit is missing or duplicated.'
        }
        $checks.Add('sharing_revocation_projection_purge_and_task_close')
    }

    if ($IncludeGt4Management) {
        $audit = Request POST `
            '/rest/v1/rpc/list_learning_group_moderation_events' `
            $teacherA.Headers @{p_group_id=$groupId; p_limit=100}
        Status $audit @(200) 'GT4 owner moderation audit'
        $auditActions = @($audit.Json | ForEach-Object { [string]$_.action })
        foreach ($requiredAction in @(
            'group_created', 'invite_rotated', 'announcement_created',
            'join_approved', 'join_rejected'
        )) {
            if ($requiredAction -notin $auditActions) {
                throw "GT4 moderation audit is missing $requiredAction."
            }
        }
        if (@($audit.Json | Where-Object {
            $_.PSObject.Properties.Name -contains 'request_id'
        }).Count -ne 0) {
            throw 'GT4 moderation projection disclosed request identifiers.'
        }
        Status (Request POST `
            '/rest/v1/rpc/list_learning_group_moderation_events' `
            $studentA.Headers @{p_group_id=$groupId; p_limit=100}) `
            @(400, 401, 403) 'GT4 student moderation audit rejection'
        $checks.Add('owner_only_bounded_moderation_audit_projection')
    }

    if ($IncludeGt3Chat) {
        $rejoinForChat = Request POST '/rest/v1/rpc/request_learning_group_join' `
            $studentB.Headers @{
                p_invite_token = $invite
                p_request_id = [guid]::NewGuid().ToString()
            }
        Status $rejoinForChat @(200) 'GT3 second student rejoin'
        if ([string]$rejoinForChat.Json -ne $groupId) {
            throw 'GT3 second student rejoin returned wrong group.'
        }
        $approveForChat = Request POST '/rest/v1/rpc/respond_learning_group_join' `
            $teacherA.Headers @{
                p_group_id = $groupId
                p_student_user_id = $studentB.Id
                p_decision = 'approve'
                p_request_id = [guid]::NewGuid().ToString()
                p_reason_code = $null
            }
        Status $approveForChat @(200) 'GT3 second student approval'
        if ($approveForChat.Json -ne 'active') {
            throw 'GT3 second student approval did not return active.'
        }

        $conversation = Request GET `
            "/rest/v1/chat_conversations?learning_group_id=eq.$groupId&select=id,kind,learning_group_id" `
            $teacherA.Headers $null
        Status $conversation @(200) 'GT3 group conversation lookup'
        if (@($conversation.Json).Count -ne 1 -or
            $conversation.Json[0].kind -ne 'group' -or
            $conversation.Json[0].learning_group_id -ne $groupId) {
            throw 'GT3 group conversation shape is invalid.'
        }
        $conversationId = [string]$conversation.Json[0].id
        $members = Request GET `
            "/rest/v1/chat_members?conversation_id=eq.$conversationId&left_at=is.null&select=user_id" `
            $teacherA.Headers $null
        Status $members @(200) 'GT3 active chat membership lookup'
        $memberIds = @($members.Json | ForEach-Object { [string]$_.user_id })
        $expectedMemberIds = @($teacherA.Id, $studentA.Id, $studentB.Id)
        if ($memberIds.Count -ne 3 -or
            @($expectedMemberIds | Where-Object {
                $_ -notin $memberIds
            }).Count -ne 0) {
            throw 'GT3 group chat membership did not mirror three active members.'
        }
        Empty (Request GET `
            "/rest/v1/chat_conversations?id=eq.$conversationId&select=id" `
            $studentC.Headers $null) 'GT3 outsider conversation denial'

        $messageId = [guid]::NewGuid().ToString()
        $messageMarker = "GT3 realtime $runId"
        $smokeEnvironment = @{
            CAPY_GT3_SUPABASE_URL = $baseUrl
            CAPY_GT3_ANON_KEY = $anonValue
            CAPY_GT3_TEACHER_EMAIL = $teacherA.Email
            CAPY_GT3_TEACHER_PASSWORD = $teacherA.Password
            CAPY_GT3_STUDENT_A_EMAIL = $studentA.Email
            CAPY_GT3_STUDENT_A_PASSWORD = $studentA.Password
            CAPY_GT3_STUDENT_B_EMAIL = $studentB.Email
            CAPY_GT3_STUDENT_B_PASSWORD = $studentB.Password
            CAPY_GT3_CONVERSATION_ID = $conversationId
            CAPY_GT3_MESSAGE_ID = $messageId
            CAPY_GT3_MESSAGE_MARKER = $messageMarker
        }
        $previousGt3Environment = @{}
        try {
            foreach ($name in $smokeEnvironment.Keys) {
                $previousGt3Environment[$name] =
                    [Environment]::GetEnvironmentVariable($name, 'Process')
                [Environment]::SetEnvironmentVariable(
                    $name, $smokeEnvironment[$name], 'Process'
                )
            }
            & flutter test tool/group_gt3_realtime_smoke_test.dart
            if ($LASTEXITCODE -ne 0) {
                throw 'GT3 three-client Realtime smoke failed.'
            }
        }
        finally {
            foreach ($name in $previousGt3Environment.Keys) {
                [Environment]::SetEnvironmentVariable(
                    $name, $previousGt3Environment[$name], 'Process'
                )
            }
        }
        $checks.Add('three_active_members_group_conversation_and_raw_realtime')

        $translationDeadline = [DateTime]::UtcNow.AddSeconds(60)
        do {
            Start-Sleep -Milliseconds 500
            $translation = Request GET `
                "/rest/v1/chat_translations?message_id=eq.$messageId&select=id,target_language_code,translated_text,status,attempt_count,error_code,provider,model,prompt_version,translator_version" `
                $studentA.Headers $null
            Status $translation @(200) 'GT3 shared translation read'
            if (@($translation.Json).Count -gt 1) {
                throw 'GT3 worker created duplicate translations.'
            }
            if (@($translation.Json).Count -eq 1 -and
                $translation.Json[0].status -eq 'failed') {
                $safeError = if ($translation.Json[0].error_code -match '^[a-z0-9_]+$') {
                    $translation.Json[0].error_code
                } else { 'unavailable' }
                throw "GT3 worker translation failed: error_code=$safeError."
            }
        } while ((@($translation.Json).Count -ne 1 -or
            $translation.Json[0].status -ne 'succeeded') -and
            [DateTime]::UtcNow -lt $translationDeadline)
        if (@($translation.Json).Count -ne 1 -or
            $translation.Json[0].status -ne 'succeeded' -or
            $translation.Json[0].target_language_code -ne 'en' -or
            $translation.Json[0].provider -ne 'gemini' -or
            $translation.Json[0].model -ne 'gemini-3-flash-preview' -or
            $translation.Json[0].prompt_version -ne 'chat-translate-p3' -or
            $translation.Json[0].translator_version -ne 'chat-translate-v3' -or
            [string]::IsNullOrWhiteSpace($translation.Json[0].translated_text)) {
            throw 'GT3 shared translation did not reach the Gemini v3 success contract.'
        }
        $translationMode = 'succeeded'
        foreach ($member in @($teacherA, $studentA, $studentB)) {
            $shared = Request GET `
                "/rest/v1/chat_translations?message_id=eq.$messageId&select=id,status" `
                $member.Headers $null
            Status $shared @(200) 'GT3 member translation read'
            if (@($shared.Json).Count -ne 1 -or
                $shared.Json[0].status -ne $translation.Json[0].status) {
                throw 'GT3 translation was not shared with every active member.'
            }
        }

        $correction = @{
            id = [guid]::NewGuid().ToString()
            message_id = $messageId
            author_id = $studentA.Id
            target_language_code = 'en'
            proposed_text = 'Blocked group correction'
        }
        Status (Request POST '/rest/v1/chat_corrections' `
            $studentA.Headers $correction) @(400, 403) `
            'GT3 direct-only correction rejection'

        $hideRequest = [guid]::NewGuid().ToString()
        $hidden = Request POST '/rest/v1/rpc/moderate_learning_group_message' `
            $teacherA.Headers @{
                p_group_id = $groupId
                p_message_id = $messageId
                p_visibility = 'hidden'
                p_request_id = $hideRequest
                p_reason_code = 'gt3_smoke'
            }
        Status $hidden @(200) 'GT3 owner moderation hide'
        if ($hidden.Json -ne $true) { throw 'GT3 hide returned false.' }
        Empty (Request GET `
            "/rest/v1/chat_operational_messages?id=eq.$messageId&select=id" `
            $studentA.Headers $null) 'GT3 hidden message visibility'
        Status (Request POST '/rest/v1/rpc/moderate_learning_group_message' `
            $studentC.Headers @{
                p_group_id = $groupId
                p_message_id = $messageId
                p_visibility = 'visible'
                p_request_id = [guid]::NewGuid().ToString()
                p_reason_code = $null
            }) @(400, 401, 403) 'GT3 outsider moderation rejection'
        $restored = Request POST '/rest/v1/rpc/moderate_learning_group_message' `
            $teacherA.Headers @{
                p_group_id = $groupId
                p_message_id = $messageId
                p_visibility = 'visible'
                p_request_id = [guid]::NewGuid().ToString()
                p_reason_code = $null
            }
        Status $restored @(200) 'GT3 owner moderation restore'
        if ($restored.Json -ne $true) { throw 'GT3 restore returned false.' }
        $checks.Add('shared_translation_direct_only_learning_and_audited_moderation')
    }

    $realtimeMarker = "gt2-realtime-$runId"
    $realtimeRequest = [guid]::NewGuid().ToString()
    $smokeEnvironment = @{
        CAPY_GT2_SUPABASE_URL = $baseUrl
        CAPY_GT2_ANON_KEY = $anonValue
        CAPY_GT2_TEACHER_EMAIL = $teacherA.Email
        CAPY_GT2_TEACHER_PASSWORD = $teacherA.Password
        CAPY_GT2_STUDENT_EMAIL = $studentA.Email
        CAPY_GT2_STUDENT_PASSWORD = $studentA.Password
        CAPY_GT2_GROUP_ID = $groupId
        CAPY_GT2_REALTIME_MARKER = $realtimeMarker
        CAPY_GT2_REALTIME_REQUEST_ID = $realtimeRequest
    }
    $previousSmokeEnvironment = @{}
    try {
        foreach ($name in $smokeEnvironment.Keys) {
            $previousSmokeEnvironment[$name] =
                [Environment]::GetEnvironmentVariable($name, 'Process')
            [Environment]::SetEnvironmentVariable(
                $name, $smokeEnvironment[$name], 'Process'
            )
        }
        & flutter test tool/group_gt2_realtime_smoke_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'GT2 multi-client Realtime smoke failed.' }
    }
    finally {
        foreach ($name in $previousSmokeEnvironment.Keys) {
            [Environment]::SetEnvironmentVariable(
                $name, $previousSmokeEnvironment[$name], 'Process'
            )
        }
    }
    $checks.Add('multi_client_announcement_realtime')

    $pin = Request POST `
        '/rest/v1/rpc/set_learning_group_announcement_pinned' `
        $teacherA.Headers @{
            p_group_id = $groupId
            p_announcement_id = $announcementId
            p_is_pinned = $true
            p_request_id = [guid]::NewGuid().ToString()
        }
    Status $pin @(200) 'Announcement pin'
    if ($pin.Json -ne $true) { throw 'Announcement pin returned false.' }
    foreach ($muted in @($true, $false)) {
        $mute = Request POST '/rest/v1/rpc/set_learning_group_member_mute' `
            $teacherA.Headers @{
                p_group_id = $groupId
                p_student_user_id = $studentA.Id
                p_is_muted = $muted
                p_request_id = [guid]::NewGuid().ToString()
                p_reason_code = $null
            }
        Status $mute @(200) 'Member mute transition'
        if ($mute.Json -ne $true) { throw 'Member mute transition returned false.' }
        if ($IncludeGt3Chat -and $muted) {
            $mutedMessage = @{
                id = [guid]::NewGuid().ToString()
                conversation_id = $conversationId
                sender_id = $studentA.Id
                raw_text = 'Muted student must not send'
                source_language_code = 'vi'
                client_generated_id = [guid]::NewGuid().ToString()
                client_created_at = [DateTime]::UtcNow.ToString('o')
            }
            Status (Request POST '/rest/v1/chat_operational_messages' `
                $studentA.Headers $mutedMessage) @(403) 'GT3 muted send rejection'
            $readWhileMuted = Request GET `
                "/rest/v1/chat_operational_messages?id=eq.$messageId&select=id" `
                $studentA.Headers $null
            Status $readWhileMuted @(200) 'GT3 muted history read'
            if (@($readWhileMuted.Json).Count -ne 1) {
                throw 'GT3 muted student lost read access.'
            }
        }
    }
    $remove = Request POST '/rest/v1/rpc/remove_learning_group_member' `
        $teacherA.Headers @{
            p_group_id = $groupId
            p_student_user_id = $studentA.Id
            p_request_id = [guid]::NewGuid().ToString()
            p_reason_code = 'gt2_smoke'
        }
    Status $remove @(200) 'Member removal'
    if ($remove.Json -ne $true) { throw 'Member removal returned false.' }
    $removedGroups = Request POST '/rest/v1/rpc/list_my_learning_groups' `
        $studentA.Headers @{}
    Status $removedGroups @(200) 'Removed member group list'
    if (@($removedGroups.Json).Count -ne 0) {
        throw 'Removed student retained group visibility.'
    }
    if ($IncludeGt3Chat) {
        Empty (Request GET `
            "/rest/v1/chat_operational_messages?id=eq.$messageId&select=id" `
            $studentA.Headers $null) 'GT3 removed member history denial'
        $checks.Add('mute_read_only_and_removal_immediate_chat_revocation')
    }
    $checks.Add('pin_mute_unmute_remove_and_immediate_access_loss')

    if (-not $IncludeGt3Chat) {
        $rejoin = Request POST '/rest/v1/rpc/request_learning_group_join' `
            $studentB.Headers @{
                p_invite_token = $invite
                p_request_id = [guid]::NewGuid().ToString()
            }
        Status $rejoin @(200) 'Rejected student rejoin'
        if ([string]$rejoin.Json -ne $groupId) {
            throw 'Rejoin returned wrong group.'
        }
        $reapprove = Request POST '/rest/v1/rpc/respond_learning_group_join' `
            $teacherA.Headers @{
                p_group_id = $groupId
                p_student_user_id = $studentB.Id
                p_decision = 'approve'
                p_request_id = [guid]::NewGuid().ToString()
                p_reason_code = $null
            }
        Status $reapprove @(200) 'Rejoined student approval'
    }
    $leave = Request POST '/rest/v1/rpc/leave_learning_group' `
        $studentB.Headers @{
            p_group_id = $groupId
            p_request_id = [guid]::NewGuid().ToString()
        }
    Status $leave @(200) 'Student leave'
    if ($leave.Json -ne $true) { throw 'Student leave returned false.' }
    $archive = Request POST '/rest/v1/rpc/archive_learning_group' `
        $teacherA.Headers @{
            p_group_id = $groupId
            p_request_id = [guid]::NewGuid().ToString()
        }
    Status $archive @(200) 'Group archive'
    if ($archive.Json -ne $true) { throw 'Group archive returned false.' }
    $archivedJoin = Request POST '/rest/v1/rpc/request_learning_group_join' `
        $studentC.Headers @{
            p_invite_token = $invite
            p_request_id = [guid]::NewGuid().ToString()
        }
    Status $archivedJoin @(200) 'Archived invite rejection'
    if ($null -ne $archivedJoin.Json) {
        throw 'Archived group invite remained usable.'
    }
    if ($IncludeGt4Management) {
        $archivedInvite = Request POST `
            '/rest/v1/rpc/get_learning_group_invite_status' `
            $teacherA.Headers @{p_group_id=$groupId}
        Status $archivedInvite @(200) 'GT4 archived invite metadata'
        if (@($archivedInvite.Json).Count -ne 1 -or
            $archivedInvite.Json[0].has_active_invite -ne $false) {
            throw 'GT4 archived invite metadata remained active.'
        }
        $archivedAudit = Request POST `
            '/rest/v1/rpc/list_learning_group_moderation_events' `
            $teacherA.Headers @{p_group_id=$groupId; p_limit=1}
        Status $archivedAudit @(200) 'GT4 archived moderation audit'
        if (@($archivedAudit.Json).Count -ne 1 -or
            $archivedAudit.Json[0].action -ne 'group_archived') {
            throw 'GT4 archived owner did not retain latest audit event.'
        }
        $checks.Add('archived_owner_invite_revocation_and_audit_read')
    }
    if ($IncludeGt3Chat) {
        $archivedMessage = @{
            id = [guid]::NewGuid().ToString()
            conversation_id = $conversationId
            sender_id = $teacherA.Id
            raw_text = 'Archived group must be read only'
            source_language_code = 'vi'
            client_generated_id = [guid]::NewGuid().ToString()
            client_created_at = [DateTime]::UtcNow.ToString('o')
        }
        Status (Request POST '/rest/v1/chat_operational_messages' `
            $teacherA.Headers $archivedMessage) @(403) `
            'GT3 archived send rejection'
        $archivedHistory = Request GET `
            "/rest/v1/chat_operational_messages?id=eq.$messageId&select=id" `
            $teacherA.Headers $null
        Status $archivedHistory @(200) 'GT3 archived history read'
        if (@($archivedHistory.Json).Count -ne 1) {
            throw 'GT3 archived owner lost history access.'
        }
        $checks.Add('archived_group_chat_read_only_with_history_preserved')
    }
    $checks.Add('rejoin_leave_archive_and_invite_revocation')
}
catch {
    $primaryFailure = $_
}
finally {
    try {
        if ($adminHeaders) {
            try {
                if ($groupId) {
                    Remove-AndAssertDatabaseFixture $groupId $teacherA.Id `
                        $conversationId $messageId $lessonResultId `
                        $studentA.Id $lessonMissionDate
                }
            }
            catch { $cleanupErrors.Add('database_rows') }
            foreach ($id in $fixtureIds) {
                try {
                    $fixture = Request GET "/auth/v1/admin/users/$id" `
                        $adminHeaders $null
                    Status $fixture @(200) 'Cleanup identity read'
                    if ($fixture.Json.user_metadata.test_scope -ne $scope -or
                        $fixture.Json.user_metadata.run_id -ne $runId) {
                        throw 'Fixture identity does not match this run.'
                    }
                    Status (Request DELETE "/auth/v1/admin/users/$id" `
                        $adminHeaders $null) @(200, 204) 'Fixture deletion'
                }
                catch {
                    $cleanupErrors.Add("auth:$id")
                }
            }
            try {
                if ((Get-ScopeFixtureCount $adminHeaders) -ne 0) {
                    throw 'Auth fixture count is not zero.'
                }
            }
            catch { $cleanupErrors.Add('auth_inventory') }
            if ($cleanupErrors.Count -eq 0) {
                $checks.Add('auth_group_invite_member_announcement_audit_cleanup_zero')
            }
        }
    }
    finally {
        $keysText=$null; $keys=$null; $anonValue=$null; $adminValue=$null
        $anonHeaders=$null; $adminHeaders=$null
        $smokeEnvironment=$null; $previousSmokeEnvironment=$null
        Pop-Location
    }
}

if ($cleanupErrors.Count -gt 0) {
    $primaryCategory = if ($primaryFailure) {
        $primaryFailure.Exception.Message
    } else {
        'none'
    }
    throw "$label smoke primary failure: $primaryCategory; cleanup failed in bounded categories: $($cleanupErrors -join ', ')."
}
if ($primaryFailure) { throw $primaryFailure }

[pscustomobject]@{
    status = 'VERIFIED'
    project_ref = $stagingRef
    checks = $checks.ToArray()
    fixture_count_remaining = 0
    database_fixture_rows_remaining = 0
    translation_mode = $translationMode
} | ConvertTo-Json -Depth 4
