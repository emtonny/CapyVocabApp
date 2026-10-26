#requires -Version 7.0
# Exact-Staging smoke. Synthetic text/accounts only; invokes live Chat Gemini once.
param(
    [string]$ProjectRef = 'nxteaznowkfennxpqjmt',
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
$expectedRef = 'nxteaznowkfennxpqjmt'
$expectedName = "emtonny's Project"
$scope = 'c4g_chat_translation_e2e'
$runId = [guid]::NewGuid().ToString('N')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$baseUrl = "https://$expectedRef.supabase.co"
$functionUrl = "$baseUrl/functions/v1/chat-translation-worker"
$triggerSecret = [Environment]::GetEnvironmentVariable(
    'CHAT_TRANSLATION_TRIGGER_SECRET', 'Process'
)
$fixtureIds = [Collections.Generic.HashSet[string]]::new()
$accounts = [Collections.Generic.List[object]]::new()
$baseline = @{}
$conversationId = $null
$messageId = $null

function Test-MigrationAppliedExactlyOnce(
    [string]$MigrationText,
    [string]$Version
) {
    try {
        $history = ConvertFrom-Json $MigrationText
        if ($null -ne $history.migrations) {
            return @($history.migrations | Where-Object {
                $_.local -eq $Version -and $_.remote -eq $Version
            }).Count -eq 1
        }
    }
    catch { }

    $escaped = [regex]::Escape($Version)
    $appliedLine = '(?m)^\s*`?' + $escaped +
        '`?\s*\|\s*`?' + $escaped + '`?\s*\|'
    return @([regex]::Matches($MigrationText, $appliedLine)).Count -eq 1
}

if ($SelfTest) {
    $tableSample = @'
   Local            | Remote           | Time (UTC)
  ------------------|------------------|-----------------------
   `20260918120000` | `20260918120000` | `2026-09-18 12:00:00`
   `20260918125000` | ` `              | `2026-09-18 12:50:00`
'@
    $jsonSample = @'
{"migrations":[{"local":"20260918120000","remote":"20260918120000"},{"local":"20260918125000","remote":null}],"message":"Migrations listed"}
'@
    if (-not (Test-MigrationAppliedExactlyOnce $tableSample '20260918120000') -or
        (Test-MigrationAppliedExactlyOnce $tableSample '20260918125000') -or
        -not (Test-MigrationAppliedExactlyOnce $jsonSample '20260918120000') -or
        (Test-MigrationAppliedExactlyOnce $jsonSample '20260918125000')) {
        throw 'Migration history parser self-test failed.'
    }
    Write-Host 'C4G runner self-test passed: JSON/table migration parser.'
    exit 0
}

if ($ProjectRef -cne $expectedRef) {
    throw 'Refusing C4G: only the fixed exact-Staging project is allowed.'
}
if ([string]::IsNullOrWhiteSpace($triggerSecret) -or
    $triggerSecret -cnotmatch '^[A-Za-z0-9_-]{32,256}$') {
    throw 'Set the process-only CHAT_TRANSLATION_TRIGGER_SECRET (32-256 base64url characters).'
}

function Request(
    [string]$Method,
    [string]$Uri,
    [hashtable]$Headers,
    [object]$Body
) {
    try {
        $parameters = @{
            Method = $Method
            Uri = $Uri
            Headers = $Headers
            TimeoutSec = 30
            SkipHttpErrorCheck = $true
        }
        if ($null -ne $Body) {
            $parameters.ContentType = 'application/json'
            $parameters.Body = $Body | ConvertTo-Json -Depth 10 -Compress
        }
        $response = Invoke-WebRequest @parameters
        $json = if ($response.Content) {
            ConvertFrom-Json $response.Content -NoEnumerate
        } else { $null }
        return [pscustomobject]@{
            Status = [int]$response.StatusCode
            Json = $json
            Range = ($response.Headers['Content-Range'] -join ',')
        }
    }
    catch {
        throw 'C4G transport/JSON failure; response bodies and credentials were not logged.'
    }
}

function Rest(
    [string]$Method,
    [string]$Path,
    [hashtable]$Headers,
    [object]$Body
) {
    return Request $Method "$baseUrl$Path" $Headers $Body
}

function Status($Response, [int[]]$Expected, [string]$Label) {
    if ($Response.Status -notin $Expected) {
        $code = if ($Response.Json.code -match '^[a-zA-Z0-9_]+$') {
            $Response.Json.code
        } else { 'unavailable' }
        throw "$Label failed: HTTP $($Response.Status), code=$code."
    }
}

function Empty($Response, [string]$Label) {
    Status $Response @(200) $Label
    if ($Response.Json -isnot [array] -or $Response.Json.Count -ne 0) {
        throw "$Label expected an empty array."
    }
}

function Count-Rows([string]$Table) {
    $response = Rest HEAD "/rest/v1/$Table`?select=*&limit=0" $adminHeaders $null
    Status $response @(200, 206) "Baseline count for $Table"
    if ($response.Range -notmatch '/([0-9]+)$') {
        throw "Exact baseline count unavailable for $Table."
    }
    return [int]$Matches[1]
}

function Fixtures {
    $found = [Collections.Generic.List[object]]::new()
    for ($page = 1; $page -le 20; $page++) {
        $response = Rest GET "/auth/v1/admin/users?page=$page&per_page=100" `
            $adminHeaders $null
        Status $response @(200) 'Fixture inventory'
        foreach ($user in @($response.Json.users)) {
            if ($user.user_metadata.test_scope -eq $scope -and
                $user.user_metadata.run_id -eq $runId) {
                $found.Add($user)
            }
        }
        if (@($response.Json.users).Count -lt 100) { return $found.ToArray() }
    }
    throw 'Fixture inventory truncated; refusing broad cleanup.'
}

function Invoke-WorkerBurst([int]$Count) {
    Add-Type -AssemblyName System.Net.Http
    $client = [Net.Http.HttpClient]::new()
    $client.Timeout = [TimeSpan]::FromSeconds(30)
    $requests = [Collections.Generic.List[Net.Http.HttpRequestMessage]]::new()
    $tasks = @()
    try {
        for ($index = 0; $index -lt $Count; $index++) {
            $request = [Net.Http.HttpRequestMessage]::new(
                [Net.Http.HttpMethod]::Post, $functionUrl
            )
            $null = $request.Headers.TryAddWithoutValidation(
                'X-Chat-Translation-Trigger', $triggerSecret
            )
            $request.Content = [Net.Http.StringContent]::new(
                '{}', [Text.Encoding]::UTF8, 'application/json'
            )
            $requests.Add($request)
            $tasks += $client.SendAsync($request)
        }
        [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]$tasks)
        $results = [Collections.Generic.List[object]]::new()
        foreach ($task in $tasks) {
            $response = $task.GetAwaiter().GetResult()
            try {
                $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                $json = if ($content) { ConvertFrom-Json $content -NoEnumerate } else { $null }
                $results.Add([pscustomobject]@{
                    Status = [int]$response.StatusCode
                    Json = $json
                })
            }
            finally { $response.Dispose() }
        }
        return $results.ToArray()
    }
    catch {
        throw 'C4G concurrent worker invocation failed; credentials and bodies were not logged.'
    }
    finally {
        foreach ($request in $requests) { $request.Dispose() }
        $client.Dispose()
    }
}

Push-Location $repoRoot
try {
    $projectsText = (& npx.cmd supabase projects list --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to verify exact Staging.' }
    $project = @(ConvertFrom-Json $projectsText | Where-Object {
        $_.ref -eq $expectedRef
    })
    if ($project.Count -ne 1 -or $project[0].name -cne $expectedName -or
        $project[0].status -ne 'ACTIVE_HEALTHY' -or -not $project[0].linked) {
        throw 'Refusing C4G: linked project is not the expected healthy Staging target.'
    }

    $migrationText = (& npx.cmd supabase migration list --project-ref `
        $expectedRef | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to verify Staging migration history.' }
    foreach ($requiredMigration in @(
        '20260918120000',
        '20260918125000',
        '20260918130000',
        '20260921120000',
        '20261021110000'
    )) {
        if (-not (Test-MigrationAppliedExactlyOnce `
            $migrationText $requiredMigration)) {
            throw "Required C4 migration is not applied exactly once on Staging: $requiredMigration."
        }
    }

    $functionsText = (& npx.cmd supabase functions list --project-ref `
        $expectedRef --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to verify Staging Edge Functions.' }
    $worker = @(ConvertFrom-Json $functionsText | Where-Object {
        $_.slug -eq 'chat-translation-worker'
    })
    if ($worker.Count -ne 1 -or $worker[0].status -ne 'ACTIVE' -or
        $worker[0].verify_jwt -ne $false) {
        throw 'Chat translation worker is not the one active internal-trigger function.'
    }

    $secretsText = (& npx.cmd supabase secrets list --project-ref `
        $expectedRef --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to verify Staging secret names.' }
    $secretNames = @(ConvertFrom-Json $secretsText | ForEach-Object { $_.name })
    foreach ($required in @(
        'CHAT_TRANSLATION_TRIGGER_SECRET', 'CHAT_TRANSLATION_API_KEY',
        'CHAT_TRANSLATION_BASE_URL', 'CHAT_TRANSLATION_PROVIDER'
    )) {
        if ($required -notin $secretNames) {
            throw "Required Staging secret is absent: $required."
        }
    }

    $keysText = (& npx.cmd supabase projects api-keys --project-ref `
        $expectedRef --reveal --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to obtain bounded smoke credentials.' }
    $keys = @(ConvertFrom-Json $keysText)
    $public = @($keys | Where-Object { $_.type -eq 'publishable' } |
        Select-Object -First 1)
    if ($public.Count -eq 0) {
        $public = @($keys | Where-Object {
            $_.name -eq 'anon' -or $_.id -eq 'anon'
        } | Select-Object -First 1)
    }
    $admin = @($keys | Where-Object { $_.type -eq 'secret' } |
        Select-Object -First 1)
    if ($admin.Count -eq 0) {
        $admin = @($keys | Where-Object {
            $_.name -eq 'service_role' -or $_.id -eq 'service_role'
        } | Select-Object -First 1)
    }
    if ($public.Count -ne 1 -or $admin.Count -ne 1) {
        throw 'Required Staging API keys are unavailable.'
    }
    $publicValue = if ($public[0].api_key) { $public[0].api_key } else { $public[0].key }
    $adminValue = if ($admin[0].api_key) { $admin[0].api_key } else { $admin[0].key }
    if (-not $publicValue -or -not $adminValue) {
        throw 'Unsupported Staging API key shape.'
    }
    $anonHeaders = @{apikey = $publicValue; 'User-Agent' = 'capy-c4g-smoke/1.0'}
    $adminHeaders = @{
        apikey = $adminValue
        Authorization = "Bearer $adminValue"
        Prefer = 'return=representation,count=exact'
        'User-Agent' = 'capy-c4g-smoke/1.0'
    }

    foreach ($table in @(
        'chat_conversations', 'chat_members', 'chat_operational_messages',
        'chat_translations', 'chat_corrections'
    )) {
        $baseline[$table] = Count-Rows $table
    }

    Status (Request POST $functionUrl @{} @{}) @(401) 'Missing trigger denial'
    Status (Request POST $functionUrl @{
        'X-Chat-Translation-Trigger' = 'invalid-c4g-trigger-value-00000000'
    } @{}) @(401) 'Invalid trigger denial'

    for ($index = 1; $index -le 3; $index++) {
        $email = "c4g-$runId-$index@example.invalid"
        $password = "C4g!$([guid]::NewGuid().ToString('N'))"
        $created = Rest POST '/auth/v1/admin/users' $adminHeaders @{
            email = $email
            password = $password
            email_confirm = $true
            user_metadata = @{test_scope = $scope; run_id = $runId}
        }
        Status $created @(200, 201) 'Fixture creation'
        $id = [string]$created.Json.id
        if ($id -notmatch '^[0-9a-f-]{36}$') { throw 'Fixture identity missing.' }
        $null = $fixtureIds.Add($id)
        $login = Rest POST '/auth/v1/token?grant_type=password' $anonHeaders @{
            email = $email
            password = $password
        }
        Status $login @(200) 'Fixture sign-in'
        if ($login.Json.user.id -ne $id -or -not $login.Json.access_token) {
            throw 'Fixture session mismatch.'
        }
        $ownerHeaders = @{
            apikey = $publicValue
            Authorization = "Bearer $($login.Json.access_token)"
            Prefer = 'return=representation'
            'User-Agent' = 'capy-c4g-smoke/1.0'
        }
        $native = if ($index -eq 1) { 'vi' } else { 'en' }
        $learning = if ($native -eq 'vi') { 'en' } else { 'vi' }
        $interfaceLocale = if ($native -eq 'vi') { 'vi-VN' } else { 'en-US' }
        $learningLocale = if ($learning -eq 'vi') { 'vi-VN' } else { 'en-US' }
        $completed = Rest POST '/rest/v1/rpc/complete_onboarding' $ownerHeaders @{
            p_display_name = "C4G fixture $index"
            p_username = "c4g$($runId.Substring(0, 14))$index"
            p_age = 25
            p_phone = '0' + (Get-Random -Minimum 100000000 -Maximum 1000000000)
            p_account_role = 'personal'
            p_interface_locale = $interfaceLocale
            p_learning_locale = $learningLocale
            p_reminder_time = '22:00'
            p_study_end_time = '02:00'
            p_daily_target_words = 10
            p_native_language_code = $native
            p_learning_language_code = $learning
            p_proficiency_level = 'beginner'
        }
        Status $completed @(200) 'Fixture onboarding'
        if ($completed.Json -ne $true) { throw 'Fixture onboarding incomplete.' }
        $accounts.Add([pscustomobject]@{Id = $id; Headers = $ownerHeaders})
    }

    $a = $accounts[0]
    $b = $accounts[1]
    $outsider = $accounts[2]
    Status (Rest POST '/rest/v1/friends' $a.Headers @{
        user_id = $a.Id; friend_id = $b.Id; status = 'pending'
    }) @(201) 'Friend request'
    $friendFilter = "/rest/v1/friends?user_id=eq.$($a.Id)&friend_id=eq.$($b.Id)"
    Status (Rest PATCH $friendFilter $b.Headers @{status = 'accepted'}) @(200) `
        'Friend acceptance'
    Status (Rest POST '/rest/v1/friends' $b.Headers @{
        user_id = $b.Id; friend_id = $a.Id; status = 'accepted'
    }) @(201) 'Reciprocal friend mirror'
    $opened = Rest POST '/rest/v1/rpc/open_direct_chat' $a.Headers @{
        p_peer_id = $b.Id
    }
    Status $opened @(200) 'Direct chat open'
    $conversationId = [string]$opened.Json
    if ($conversationId -notmatch '^[0-9a-f-]{36}$') {
        throw 'Conversation identity missing.'
    }

    $messageId = [guid]::NewGuid().ToString()
    $raw = @{
        id = $messageId
        conversation_id = $conversationId
        sender_id = $a.Id
        raw_text = 'C4G synthetic: Chúc bạn một ngày học tập hiệu quả.'
        source_language_code = 'vi'
        client_generated_id = [guid]::NewGuid().ToString()
        client_created_at = [DateTime]::UtcNow.ToString('o')
    }
    Status (Rest POST '/rest/v1/chat_operational_messages' $a.Headers $raw) `
        @(201) 'Raw message insert'
    foreach ($member in @($a, $b)) {
        $visibleRaw = Rest GET `
            "/rest/v1/chat_operational_messages?id=eq.$messageId&select=id" `
            $member.Headers $null
        Status $visibleRaw @(200) 'Member raw read'
        if ($visibleRaw.Json.Count -ne 1) { throw 'Member cannot read raw before translation.' }
    }
    $queued = Rest GET `
        "/rest/v1/chat_translations?message_id=eq.$messageId&select=id,status,attempt_count,translated_text,target_language_code,translator_version,provider,model,prompt_version" `
        $a.Headers $null
    Status $queued @(200) 'Queued translation read'
    if ($queued.Json.Count -ne 1 -or
        $queued.Json[0].status -notin @('queued', 'processing', 'succeeded') -or
        $queued.Json[0].attempt_count -notin @(0, 1)) {
        throw 'Raw transaction did not create exactly one valid translation job.'
    }
    Status (Rest POST '/rest/v1/chat_translations' $a.Headers @{
        id = [guid]::NewGuid().ToString()
        message_id = $messageId
        target_language_code = 'en'
        translator_version = 'chat-translate-v3'
    }) @(401, 403) 'Client translation write denial'

    $burst = @(Invoke-WorkerBurst 5)
    $successResponses = @($burst | Where-Object {
        $_.Status -eq 200 -and $_.Json.status -eq 'succeeded'
    })
    $idleResponses = @($burst | Where-Object { $_.Status -eq 204 })
    if ($successResponses.Count -gt 1 -or
        ($successResponses.Count + $idleResponses.Count) -ne 5) {
        throw 'Concurrent wake-ups returned an unexpected result or more than one success.'
    }

    $translation = $null
    for ($poll = 0; $poll -lt 20; $poll++) {
        $translation = Rest GET `
            "/rest/v1/chat_translations?message_id=eq.$messageId&select=id,message_id,target_language_code,translated_text,provider,model,prompt_version,translator_version,status,attempt_count,error_code,completed_at" `
            $a.Headers $null
        Status $translation @(200) 'Successful translation read'
        if ($translation.Json.Count -eq 1 -and
            $translation.Json[0].status -eq 'succeeded') { break }
        Start-Sleep -Milliseconds 500
    }
    if ($translation.Json.Count -ne 1 -or
        $translation.Json[0].status -ne 'succeeded' -or
        $translation.Json[0].attempt_count -ne 1 -or
        [string]::IsNullOrWhiteSpace($translation.Json[0].translated_text) -or
        $translation.Json[0].provider -ne 'gemini' -or
        $translation.Json[0].model -ne 'gemini-3-flash-preview' -or
        $translation.Json[0].prompt_version -ne 'chat-translate-p3' -or
        $translation.Json[0].translator_version -ne 'chat-translate-v3' -or
        $translation.Json[0].target_language_code -ne 'en' -or
        $null -ne $translation.Json[0].error_code -or
        $null -eq $translation.Json[0].completed_at) {
        $safeContractState = [ordered]@{
            row_count = @($translation.Json).Count
            status = $translation.Json[0].status
            attempt_count = $translation.Json[0].attempt_count
            provider = $translation.Json[0].provider
            model = $translation.Json[0].model
            prompt_version = $translation.Json[0].prompt_version
            translator_version = $translation.Json[0].translator_version
            target_language_code = $translation.Json[0].target_language_code
            error_code = $translation.Json[0].error_code
            has_completed_at = $null -ne $translation.Json[0].completed_at
            has_translation = -not [string]::IsNullOrWhiteSpace(
                $translation.Json[0].translated_text
            )
        } | ConvertTo-Json -Compress
        throw "Live translation row violates the locked C4 contract: $safeContractState"
    }
    $translationId = [string]$translation.Json[0].id
    $translationText = [string]$translation.Json[0].translated_text
    foreach ($member in @($a, $b)) {
        $memberRow = Rest GET `
            "/rest/v1/chat_translations?id=eq.$translationId&select=id,translated_text,status,attempt_count" `
            $member.Headers $null
        Status $memberRow @(200) 'Shared member translation read'
        if ($memberRow.Json.Count -ne 1 -or
            $memberRow.Json[0].translated_text -cne $translationText -or
            $memberRow.Json[0].status -ne 'succeeded' -or
            $memberRow.Json[0].attempt_count -ne 1) {
            throw 'The two members did not receive the same successful row.'
        }
    }
    Empty (Rest GET `
        "/rest/v1/chat_translations?id=eq.$translationId&select=id" `
        $outsider.Headers $null) 'Outsider translation denial'

    $repeatBurst = @(Invoke-WorkerBurst 3)
    if (@($repeatBurst | Where-Object { $_.Status -eq 204 }).Count -ne 3) {
        throw 'Wake-ups after success were not all idle.'
    }
    $unchanged = Rest GET `
        "/rest/v1/chat_translations?id=eq.$translationId&select=id,status,attempt_count,translated_text" `
        $a.Headers $null
    if ($unchanged.Json.Count -ne 1 -or
        $unchanged.Json[0].attempt_count -ne 1 -or
        $unchanged.Json[0].translated_text -cne $translationText) {
        throw 'Duplicate wake-up changed the successful translation.'
    }

    [pscustomobject]@{
        status = 'VERIFIED'
        project_ref = $expectedRef
        synthetic_accounts = 3
        concurrent_wakeups = 5
        successful_workers_observed = $successResponses.Count
        idle_workers_observed = $idleResponses.Count
        provider_attempts_inferred = 1
        duplicate_post_success_wakeups = 3
        shared_member_rows = 2
        outsider_rows = 0
        training_writes = 0
        fixture_count_remaining = 0
    } | ConvertTo-Json
}
finally {
    try {
        if ($adminHeaders) {
            foreach ($fixture in @(Fixtures)) {
                $null = $fixtureIds.Add([string]$fixture.id)
            }
            foreach ($id in $fixtureIds) {
                $fixture = Rest GET "/auth/v1/admin/users/$id" $adminHeaders $null
                Status $fixture @(200) 'Cleanup identity check'
                if ($fixture.Json.user_metadata.test_scope -ne $scope -or
                    $fixture.Json.user_metadata.run_id -ne $runId) {
                    throw 'Refusing cleanup outside the exact C4G fixture scope/run.'
                }
                Status (Rest DELETE "/auth/v1/admin/users/$id" $adminHeaders $null) `
                    @(200, 204) 'Fixture account deletion'
            }
            if (@(Fixtures).Count -ne 0) { throw 'Fixture Auth cleanup incomplete.' }
            if ($conversationId) {
                Empty (Rest GET `
                    "/rest/v1/chat_conversations?id=eq.$conversationId&select=id" `
                    $adminHeaders $null) 'Conversation cascade cleanup'
            }
            foreach ($table in $baseline.Keys) {
                if ((Count-Rows $table) -ne $baseline[$table]) {
                    throw "Baseline count changed or fixture cleanup failed: $table."
                }
            }
        }
    }
    finally {
        $triggerSecret = $null
        $keysText = $null
        $keys = $null
        $publicValue = $null
        $adminValue = $null
        $translationText = $null
        $raw = $null
        $login = $null
        $password = $null
        $anonHeaders = $null
        $adminHeaders = $null
        $accounts.Clear()
        Pop-Location
    }
}
