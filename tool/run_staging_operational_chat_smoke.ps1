#requires -Version 7.0
# C2 backend smoke only. Synthetic accounts/content; no Gemini or Training calls.
# Realtime wire protocol: https://supabase.com/docs/guides/realtime/protocol
$ErrorActionPreference = 'Stop'
$stagingRef = 'nxteaznowkfennxpqjmt'
$baseUrl = "https://$stagingRef.supabase.co"
$runId = [guid]::NewGuid().ToString('N')
$scope = 'c2_operational_chat_smoke'
$fixtureIds = [Collections.Generic.HashSet[string]]::new()
$accounts = [Collections.Generic.List[object]]::new()
$sockets = [Collections.Generic.List[object]]::new()
$checks = [Collections.Generic.List[string]]::new()
$chatTables = @('chat_conversations','chat_members','chat_operational_messages','chat_translations','chat_corrections')
$baseline = @{}
$conversationId = $null
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Request([string]$Method, [string]$Path, [hashtable]$Headers, [object]$Body) {
    try {
        $params = @{Method=$Method; Uri="$baseUrl$Path"; Headers=$Headers; TimeoutSec=30; SkipHttpErrorCheck=$true}
        if ($null -ne $Body) { $params.ContentType='application/json'; $params.Body=$Body | ConvertTo-Json -Depth 10 -Compress }
        $response = Invoke-WebRequest @params
        $json = if ($response.Content) { ConvertFrom-Json $response.Content -NoEnumerate } else { $null }
        return [pscustomobject]@{Status=[int]$response.StatusCode; Json=$json; Range=($response.Headers['Content-Range'] -join ',')}
    }
    catch { throw 'C2 transport/JSON failure; response bodies, identities and credentials were not logged.' }
}
function Status($Response, [int[]]$Expected, [string]$Label) {
    if ($Response.Status -notin $Expected) {
        $code = if ($Response.Json.code -match '^[a-zA-Z0-9_]+$') { $Response.Json.code } else { 'unavailable' }
        throw "$Label failed: HTTP $($Response.Status), code=$code."
    }
}
function Empty($Response, [string]$Label) {
    Status $Response @(200) $Label
    if ($Response.Json -isnot [array] -or $Response.Json.Count -ne 0) { throw "$Label expected an empty array." }
}
function Count-Rows([string]$Table) {
    $response = Request HEAD "/rest/v1/$Table`?select=*&limit=0" $adminHeaders
    # PostgREST may return 206 for an exact-count HEAD response even at limit=0.
    # The Content-Range total below remains mandatory, so truncated/unknown counts
    # still fail closed before any fixture is created.
    Status $response @(200,206) 'Baseline count'
    if ($response.Range -notmatch '/([0-9]+)$') { throw 'Exact baseline count unavailable.' }
    return [int]$Matches[1]
}
function Fixtures {
    $found = [Collections.Generic.List[object]]::new()
    for ($page=1; $page -le 20; $page++) {
        $response = Request GET "/auth/v1/admin/users?page=$page&per_page=100" $adminHeaders
        Status $response @(200) 'Fixture inventory'
        foreach ($user in @($response.Json.users)) {
            if ($user.user_metadata.test_scope -eq $scope -and $user.user_metadata.run_id -eq $runId) { $found.Add($user) }
        }
        if (@($response.Json.users).Count -lt 100) { return $found.ToArray() }
    }
    throw 'Fixture inventory truncated; refusing broad cleanup.'
}
function Send-Frame($Connection, [string]$Event, [object]$Payload, [string]$Topic, [string]$Reference) {
    $frame = @{topic=$Topic; event=$Event; payload=$Payload; ref=$Reference; join_ref='1'} | ConvertTo-Json -Depth 12 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($frame)
    $deadline = [Threading.CancellationTokenSource]::new(10000)
    try {
        $null = $Connection.Socket.SendAsync([ArraySegment[byte]]::new($bytes), [Net.WebSockets.WebSocketMessageType]::Text, $true, $deadline.Token).GetAwaiter().GetResult()
    }
    catch { throw 'C2 Realtime send failed; frame and credentials were not logged.' }
    finally { $deadline.Dispose() }
}
function Pump($Connection) {
    if ([DateTime]::UtcNow -ge $Connection.NextHeartbeat) {
        Send-Frame $Connection heartbeat @{} phoenix ([guid]::NewGuid().ToString('N'))
        $Connection.NextHeartbeat = [DateTime]::UtcNow.AddSeconds(15)
    }
    if ($null -eq $Connection.Pending) {
        $Connection.Pending = $Connection.Socket.ReceiveAsync([ArraySegment[byte]]::new($Connection.Buffer), [Threading.CancellationToken]::None)
    }
    if (-not $Connection.Pending.Wait(20)) { return }
    try { $result = $Connection.Pending.GetAwaiter().GetResult() }
    catch { throw 'C2 Realtime receive failed; payload was not logged.' }
    $Connection.Pending = $null
    if ($result.MessageType -ne [Net.WebSockets.WebSocketMessageType]::Text) { throw 'Unexpected C2 Realtime frame type or closed socket.' }
    $Connection.Stream.Write($Connection.Buffer, 0, $result.Count)
    if ($Connection.Stream.Length -gt 262144) { throw 'C2 Realtime frame exceeded safe test limit.' }
    if (-not $result.EndOfMessage) { return }
    try { $frame = ConvertFrom-Json ([Text.Encoding]::UTF8.GetString($Connection.Stream.ToArray())) }
    catch { throw 'C2 Realtime JSON invalid; frame was not logged.' }
    $Connection.Stream.SetLength(0)
    if ($frame.event -eq 'phx_reply' -and $frame.ref -eq '1') {
        if ($frame.payload.status -ne 'ok' -or @($frame.payload.response.postgres_changes).Count -ne 5) {
            throw 'C2 Realtime join rejected or five-table subscription incomplete.'
        }
        $Connection.Joined = $true
    }
    elseif ($frame.event -eq 'system' -and $frame.payload.extension -eq 'postgres_changes') {
        if ($frame.payload.status -ne 'ok') { throw 'C2 Realtime Postgres subscription failed.' }
        $Connection.Ready = $true
    }
    elseif ($frame.event -in @('phx_error','phx_close')) { throw 'C2 Realtime channel failed/closed.' }
    elseif ($frame.event -eq 'postgres_changes') { $Connection.Events.Add($frame.payload.data) }
}
function Wait-Realtime([scriptblock]$Condition, [string]$Label, [int]$Seconds=20) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    do {
        foreach ($connection in $sockets) { Pump $connection }
        if (& $Condition) { return }
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "$Label timed out; no provider call or user data was involved."
}
function Has-Event($Connection, [string]$Table, [string]$Id) {
    return @($Connection.Events | Where-Object { $_.table -eq $Table -and $_.record.id -eq $Id }).Count -gt 0
}

Push-Location $repoRoot
try {
    $projectsText = (& npx.cmd supabase projects list --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to verify Staging.' }
    $project = @(ConvertFrom-Json $projectsText | Where-Object { $_.ref -eq $stagingRef })
    if ($project.Count -ne 1 -or $project[0].name -ne "emtonny's Project" -or
        $project[0].status -ne 'ACTIVE_HEALTHY' -or -not $project[0].linked) { throw 'Refusing C2 smoke: unexpected linked Staging.' }
    $keysText = (& npx.cmd supabase projects api-keys --project-ref $stagingRef --reveal --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to obtain Staging credentials.' }
    $keys = @(ConvertFrom-Json $keysText)
    $public = @($keys | Where-Object { $_.type -eq 'publishable' -or $_.name -eq 'anon' -or $_.id -eq 'anon' } | Select-Object -First 1)
    $admin = @($keys | Where-Object { $_.type -eq 'secret' } | Select-Object -First 1)
    if ($admin.Count -eq 0) { $admin = @($keys | Where-Object { $_.name -eq 'service_role' -or $_.id -eq 'service_role' } | Select-Object -First 1) }
    if ($public.Count -ne 1 -or $admin.Count -ne 1) { throw 'Required Staging keys missing.' }
    $publicValue = if ($public[0].api_key) { $public[0].api_key } else { $public[0].key }
    $adminValue = if ($admin[0].api_key) { $admin[0].api_key } else { $admin[0].key }
    if (-not $publicValue -or -not $adminValue) { throw 'Unsupported credential shape.' }
    $anonHeaders = @{apikey=$publicValue; 'User-Agent'='capy-c2-smoke/1.0'}
    $adminHeaders = @{apikey=$adminValue; Authorization="Bearer $adminValue"; Prefer='return=representation,count=exact'; 'User-Agent'='capy-c2-smoke/1.0'}
    foreach ($table in @($chatTables)+@('friends','chat_messages','user_language_profiles')) { $baseline[$table] = Count-Rows $table }
    for ($index=0; $index -lt 3; $index++) {
        $email = "c2-$runId-$index@example.com"
        $password = 'C2!' + [guid]::NewGuid().ToString('N')
        $created = Request POST '/auth/v1/admin/users' $adminHeaders @{
            email=$email; password=$password; email_confirm=$true; user_metadata=@{test_scope=$scope; run_id=$runId}
        }
        Status $created @(200,201) 'Fixture creation'
        $id = [string]$created.Json.id
        if ($id -notmatch '^[0-9a-f-]{36}$') { throw 'Fixture identity missing.' }
        $null = $fixtureIds.Add($id)
        $login = Request POST '/auth/v1/token?grant_type=password' $anonHeaders @{email=$email; password=$password}
        Status $login @(200) 'Fixture sign-in'
        if ($login.Json.user.id -ne $id -or -not $login.Json.access_token) { throw 'Fixture session mismatch.' }
        $owner = @{apikey=$publicValue; Authorization="Bearer $($login.Json.access_token)"; Prefer='return=representation'; 'User-Agent'='capy-c2-smoke/1.0'}
        $native = if ($index -eq 1) { 'en' } else { 'vi' }
        $learning = if ($native -eq 'vi') { 'en' } else { 'vi' }
        $completed = Request POST '/rest/v1/rpc/complete_onboarding' $owner @{
            p_display_name="C2 fixture $index"; p_username=('c2'+$runId.Substring(0,14)+$index)
            p_age=25; p_phone=('0'+(Get-Random -Minimum 100000000 -Maximum 1000000000))
            p_account_role='personal'; p_reminder_time='22:00'; p_study_end_time='02:00'; p_daily_target_words=10
            p_native_language_code=$native; p_learning_language_code=$learning; p_proficiency_level='beginner'
        }
        Status $completed @(200) 'Fixture onboarding'
        if ($completed.Json -ne $true) { throw 'Fixture onboarding incomplete.' }
        $accounts.Add([pscustomobject]@{Id=$id; Headers=$owner; Token=$login.Json.access_token})
    }
    $a=$accounts[0]; $b=$accounts[1]; $c=$accounts[2]
    Status (Request POST '/rest/v1/rpc/open_direct_chat' $a.Headers @{p_peer_id=$b.Id}) @(403) 'Stranger chat denial'
    Status (Request POST '/rest/v1/friends' $a.Headers @{user_id=$a.Id; friend_id=$b.Id; status='pending'}) @(201) 'Pending request'
    $friendFilter = "/rest/v1/friends?user_id=eq.$($a.Id)&friend_id=eq.$($b.Id)"
    Status (Request PATCH $friendFilter $a.Headers @{status='accepted'}) @(403) 'Forged acceptance denial'
    Status (Request POST '/rest/v1/rpc/open_direct_chat' $a.Headers @{p_peer_id=$b.Id}) @(403) 'Pending chat denial'
    Status (Request PATCH $friendFilter $b.Headers @{status='accepted'}) @(200) 'Recipient acceptance'
    Status (Request POST '/rest/v1/friends' $b.Headers @{user_id=$b.Id; friend_id=$a.Id; status='accepted'}) @(201) 'Reciprocal mirror'
    $mirror = $b.Headers.Clone(); $mirror.Prefer='return=representation,resolution=merge-duplicates'
    Status (Request POST '/rest/v1/friends?on_conflict=user_id,friend_id' $mirror @{user_id=$b.Id; friend_id=$a.Id; status='accepted'}) @(201,200) 'Legacy mirror UPSERT'
    $checks.Add('stranger_pending_and_forged_accept_denied_valid_friend_flow_preserved')
    $opened = Request POST '/rest/v1/rpc/open_direct_chat' $a.Headers @{p_peer_id=$b.Id}
    Status $opened @(200) 'Direct RPC'
    $conversationId = [string]$opened.Json
    if ($conversationId -notmatch '^[0-9a-f-]{36}$') { throw 'Conversation identity missing.' }
    $repeat = Request POST '/rest/v1/rpc/open_direct_chat' $b.Headers @{p_peer_id=$a.Id}
    Status $repeat @(200) 'Reversed direct RPC'
    if ($repeat.Json -ne $conversationId) { throw 'Direct RPC duplicated conversation.' }
    $members = Request GET "/rest/v1/chat_members?conversation_id=eq.$conversationId&select=user_id" $a.Headers
    Status $members @(200) 'Atomic members read'
    if ($members.Json.Count -ne 2) { throw 'Direct RPC membership incomplete.' }
    Status (Request POST '/rest/v1/chat_members' $c.Headers @{conversation_id=$conversationId; user_id=$c.Id}) @(403) 'Member injection denial'
    $checks.Add('canonical_atomic_rpc_and_no_client_membership_mutation')

    $messageId=[guid]::NewGuid().ToString(); $translationId=[guid]::NewGuid().ToString(); $correctionId=[guid]::NewGuid().ToString()
    foreach ($account in $accounts) {
        $connection = [pscustomobject]@{
            Socket=[Net.WebSockets.ClientWebSocket]::new(); Buffer=[byte[]]::new(65536)
            Stream=[IO.MemoryStream]::new(); Pending=$null; Joined=$false; Ready=$false
            NextHeartbeat=[DateTime]::UtcNow.AddSeconds(15); Events=[Collections.Generic.List[object]]::new()
            Topic="realtime:c2-$runId"
        }
        $sockets.Add($connection)
        $deadline = [Threading.CancellationTokenSource]::new(15000)
        try {
            $uri=[uri]("wss://$stagingRef.supabase.co/realtime/v1/websocket?apikey="+[uri]::EscapeDataString($publicValue)+'&vsn=1.0.0')
            $null=$connection.Socket.ConnectAsync($uri,$deadline.Token).GetAwaiter().GetResult()
        }
        catch { throw 'C2 Realtime connection failed; credentials/URI were not logged.' }
        finally { $deadline.Dispose() }
        $subscriptions = @(
            @{event='*'; schema='public'; table='chat_conversations'; filter="id=eq.$conversationId"},
            @{event='*'; schema='public'; table='chat_members'; filter="conversation_id=eq.$conversationId"},
            @{event='*'; schema='public'; table='chat_operational_messages'; filter="conversation_id=eq.$conversationId"},
            @{event='*'; schema='public'; table='chat_translations'; filter="message_id=eq.$messageId"},
            @{event='*'; schema='public'; table='chat_corrections'; filter="message_id=eq.$messageId"}
        )
        Send-Frame $connection phx_join @{config=@{broadcast=@{ack=$false; self=$false}; presence=@{enabled=$false}; private=$false; postgres_changes=$subscriptions}; access_token=$account.Token} $connection.Topic '1'
    }
    Wait-Realtime { @($sockets | Where-Object { -not $_.Joined -or -not $_.Ready }).Count -eq 0 } 'Five-table subscriptions'
    $checks.Add('three_real_websocket_sessions_five_table_subscriptions_ready')

    $raw = @{id=$messageId; conversation_id=$conversationId; sender_id=$a.Id; raw_text='C2 synthetic: Tối nay đi quẩy k bro?'; source_language_code='vi'; client_generated_id=[guid]::NewGuid().ToString(); client_created_at='2000-01-01T00:00:00Z'}
    $sent = Request POST '/rest/v1/chat_operational_messages' $a.Headers $raw
    Status $sent @(201) 'Raw message insert'
    if ($sent.Json[0].raw_text -cne $raw.raw_text -or [DateTime]$sent.Json[0].sent_at -lt [DateTime]::UtcNow.AddMinutes(-5)) { throw 'Raw text/server timestamp mismatch.' }
    Wait-Realtime { (Has-Event $sockets[0] chat_operational_messages $messageId) -and (Has-Event $sockets[1] chat_operational_messages $messageId) } 'Raw A/B relay'
    foreach ($connection in @($sockets[0],$sockets[1])) {
        $event = @($connection.Events | Where-Object { $_.table -eq 'chat_operational_messages' -and $_.record.id -eq $messageId })[0]
        if ($event.record.raw_text -cne $raw.raw_text) { throw 'Realtime raw text mismatch.' }
    }
    Empty (Request GET "/rest/v1/chat_translations?message_id=eq.$messageId&select=id" $b.Headers) 'Raw relay before translation'
    $checks.Add('raw_unicode_server_clock_realtime_both_members_before_translation')
    Status (Request POST '/rest/v1/chat_operational_messages' $a.Headers $raw) @(409) 'Idempotent duplicate'
    $spoof = $raw.Clone(); $spoof.id=[guid]::NewGuid().ToString(); $spoof.client_generated_id=[guid]::NewGuid().ToString(); $spoof.sender_id=$b.Id
    Status (Request POST '/rest/v1/chat_operational_messages' $a.Headers $spoof) @(403) 'Sender spoof denial'
    Status (Request PATCH "/rest/v1/chat_operational_messages?id=eq.$messageId" $a.Headers @{raw_text='rewrite'}) @(403) 'Client raw edit denial'
    Status (Request DELETE "/rest/v1/chat_operational_messages?id=eq.$messageId" $a.Headers) @(403) 'Client raw delete denial'
    $checks.Add('retry_no_duplicate_sender_spoof_edit_delete_denied')

    $translation = @{id=$translationId; message_id=$messageId; target_language_code='en'; translator_version='c2-synthetic-v1'; status='queued'}
    Status (Request POST '/rest/v1/chat_translations' $a.Headers $translation) @(403) 'Client provider write denial'
    Status (Request POST '/rest/v1/chat_translations' $adminHeaders $translation) @(201) 'Service translation job'
    Status (Request PATCH "/rest/v1/chat_translations?id=eq.$translationId" $adminHeaders @{
        status='succeeded'; translated_text='C2 synthetic translation for backend smoke only.'; model='synthetic-no-provider-call'; prompt_version='synthetic'; completed_at=[DateTime]::UtcNow.ToString('o'); attempt_count=1
    }) @(200) 'Service translation completion'
    Wait-Realtime {
        @($sockets[0].Events | Where-Object { $_.table -eq 'chat_translations' -and $_.record.id -eq $translationId -and $_.record.status -eq 'succeeded' }).Count -gt 0 -and
        @($sockets[1].Events | Where-Object { $_.table -eq 'chat_translations' -and $_.record.id -eq $translationId -and $_.record.status -eq 'succeeded' }).Count -gt 0
    } 'Shared translation A/B relay'
    foreach ($connection in @($sockets[0],$sockets[1])) {
        $event = @($connection.Events | Where-Object { $_.table -eq 'chat_translations' -and $_.record.id -eq $translationId -and $_.record.status -eq 'succeeded' })[0]
        if ($event.record.translated_text -cne 'C2 synthetic translation for backend smoke only.') { throw 'Shared Realtime translation content mismatch.' }
    }
    Status (Request POST '/rest/v1/chat_translations' $adminHeaders $translation) @(409) 'Translation identity unique'
    Status (Request PATCH "/rest/v1/chat_translations?id=eq.$translationId" $adminHeaders @{translated_text='rewrite'}) @(400) 'Successful translation immutable'
    $checks.Add('service_only_shared_translation_realtime_unique_and_immutable')

    $correction = @{id=$correctionId; message_id=$messageId; author_id=$b.Id; target_language_code='en'; proposed_text='C2 synthetic human correction.'}
    Status (Request POST '/rest/v1/chat_corrections' $b.Headers $correction) @(201) 'Other member correction'
    Status (Request PATCH "/rest/v1/chat_corrections?id=eq.$correctionId" $b.Headers @{status='accepted'; accepted_by=$a.Id; accepted_at=[DateTime]::UtcNow.ToString('o')}) @(403) 'Client correction decision denial'
    Status (Request PATCH "/rest/v1/chat_corrections?id=eq.$correctionId" $adminHeaders @{status='accepted'; accepted_by=$b.Id; accepted_at=[DateTime]::UtcNow.ToString('o')}) @(400) 'Wrong decision actor denial'
    Status (Request PATCH "/rest/v1/chat_corrections?id=eq.$correctionId" $adminHeaders @{status='accepted'; accepted_by=$a.Id; accepted_at=[DateTime]::UtcNow.ToString('o')}) @(200) 'Trusted correction decision'
    Wait-Realtime {
        @($sockets[0].Events | Where-Object { $_.table -eq 'chat_corrections' -and $_.record.id -eq $correctionId -and $_.record.status -eq 'accepted' }).Count -gt 0 -and
        @($sockets[1].Events | Where-Object { $_.table -eq 'chat_corrections' -and $_.record.id -eq $correctionId -and $_.record.status -eq 'accepted' }).Count -gt 0
    } 'Accepted correction A/B relay'
    $checks.Add('human_correction_separate_relay_and_sender_decision_invariant')
    foreach ($table in $chatTables) {
        $filter = if ($table -eq 'chat_conversations') { "id=eq.$conversationId" }
                  elseif ($table -in @('chat_members','chat_operational_messages')) { "conversation_id=eq.$conversationId" }
                  else { "message_id=eq.$messageId" }
        Empty (Request GET "/rest/v1/$Table`?$filter&select=*" $c.Headers) 'Outsider read denial'
        Status (Request GET "/rest/v1/$Table`?$filter&select=*" $anonHeaders) @(401,403) 'Anonymous read denial'
    }
    $watchUntil=[DateTime]::UtcNow.AddSeconds(3)
    while ([DateTime]::UtcNow -lt $watchUntil) { foreach ($connection in $sockets) { Pump $connection } }
    if ($sockets[2].Events.Count -ne 0) { throw 'Outsider received a protected Realtime event.' }
    $checks.Add('outsider_rest_all_five_tables_empty_and_realtime_zero_events_anon_denied')

    Status (Request PATCH "/rest/v1/chat_operational_messages?id=eq.$messageId" $adminHeaders @{moderation_state='held'}) @(200) 'Service moderation hold'
    foreach ($table in @('chat_operational_messages','chat_translations','chat_corrections')) {
        $filter = if ($table -eq 'chat_operational_messages') { "id=eq.$messageId" } else { "message_id=eq.$messageId" }
        Empty (Request GET "/rest/v1/$Table`?$filter&select=id" $b.Headers) 'Held content hidden'
    }
    Status (Request PATCH "/rest/v1/chat_operational_messages?id=eq.$messageId" $adminHeaders @{moderation_state='visible'}) @(200) 'Fixture hold reset'
    Status (Request PATCH "/rest/v1/chat_members?conversation_id=eq.$conversationId&user_id=eq.$($b.Id)" $adminHeaders @{left_at=[DateTime]::UtcNow.ToString('o')}) @(200) 'Fixture membership inactive'
    Empty (Request GET "/rest/v1/chat_operational_messages?conversation_id=eq.$conversationId&select=id" $b.Headers) 'Inactive member read denial'
    $another=$raw.Clone(); $another.id=[guid]::NewGuid().ToString(); $another.client_generated_id=[guid]::NewGuid().ToString()
    Status (Request POST '/rest/v1/chat_operational_messages' $a.Headers $another) @(403) 'Inactive peer send denial'
    Status (Request POST '/rest/v1/rpc/open_direct_chat' $a.Headers @{p_peer_id=$b.Id}) @(403) 'No automatic member reactivation'
    $checks.Add('held_content_hides_derived_inactive_members_fail_closed')
}
finally {
    foreach ($connection in $sockets) { $connection.Socket.Abort(); $connection.Socket.Dispose(); $connection.Stream.Dispose(); $connection.Events.Clear() }
    try {
        if ($adminHeaders) {
            foreach ($fixture in @(Fixtures)) { $null=$fixtureIds.Add([string]$fixture.id) }
            foreach ($id in $fixtureIds) {
                $fixture=Request GET "/auth/v1/admin/users/$id" $adminHeaders
                Status $fixture @(200) 'Cleanup identity check'
                if ($fixture.Json.user_metadata.test_scope -ne $scope -or $fixture.Json.user_metadata.run_id -ne $runId) { throw 'Refusing cleanup outside exact fixture scope/run.' }
                Status (Request DELETE "/auth/v1/admin/users/$id" $adminHeaders) @(200,204) 'Fixture account deletion'
            }
            if (@(Fixtures).Count -ne 0) { throw 'Fixture Auth cleanup incomplete.' }
            if ($conversationId) { Empty (Request GET "/rest/v1/chat_conversations?id=eq.$conversationId&select=id" $adminHeaders) 'Conversation cascade cleanup' }
            foreach ($table in $baseline.Keys) { if ((Count-Rows $table) -ne $baseline[$table]) { throw "Baseline count changed or fixture cleanup failed: $table." } }
            $checks.Add('fixture_auth_chat_friend_profile_cleanup_baselines_preserved')
        }
    }
    finally {
        $keysText=$null; $keys=$null; $public=$null; $admin=$null; $publicValue=$null; $adminValue=$null
        $a=$null; $b=$null; $c=$null; $login=$null; $password=$null; $owner=$null; $uri=$null
        $anonHeaders=$null; $adminHeaders=$null; $accounts.Clear(); $sockets.Clear()
        Pop-Location
    }
}
[pscustomobject]@{status='VERIFIED'; project_ref=$stagingRef; checks=$checks.ToArray(); fixture_count_remaining=0; gemini_calls=0; training_writes=0} | ConvertTo-Json -Depth 4
