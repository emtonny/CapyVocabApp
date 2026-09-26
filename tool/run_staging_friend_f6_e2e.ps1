#requires -Version 7.0
param([switch]$SelfTest)

# F6 backend E2E. Uses only synthetic accounts and never calls AI/training APIs.
$ErrorActionPreference = 'Stop'
$stagingRef = 'nxteaznowkfennxpqjmt'
$stagingName = "emtonny's Project"
$migrationVersions = @('20260922120000', '20260923120000')
$scope = 'f6_friend_management_e2e'
$runId = [guid]::NewGuid().ToString('N')
$baseUrl = "https://$stagingRef.supabase.co"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$fixtureIds = [Collections.Generic.HashSet[string]]::new()
$accounts = [Collections.Generic.List[object]]::new()
$sockets = [Collections.Generic.List[object]]::new()
$checks = [Collections.Generic.List[string]]::new()
$baseline = @{}
$baselineTables = @(
    'users', 'user_settings', 'user_language_profiles', 'friends',
    'chat_conversations', 'chat_members', 'chat_operational_messages'
)
$conversationId = $null
$adminHeaders = $null

if ($SelfTest) {
    if ($stagingRef -ne 'nxteaznowkfennxpqjmt' -or
        $migrationVersions.Count -ne 2 -or
        $migrationVersions[0] -ne '20260922120000' -or
        $migrationVersions[1] -ne '20260923120000') {
        throw 'F6 self-test constants are invalid.'
    }
    [pscustomobject]@{status='READY'; project_ref=$stagingRef; remote_writes=0} | ConvertTo-Json
    exit 0
}

function Request([string]$Method, [string]$Path, [hashtable]$Headers, [object]$Body=$null) {
    try {
        $params = @{
            Method=$Method; Uri="$baseUrl$Path"; Headers=$Headers
            TimeoutSec=30; SkipHttpErrorCheck=$true
        }
        if ($null -ne $Body) {
            $params.ContentType = 'application/json'
            $params.Body = $Body | ConvertTo-Json -Depth 10 -Compress
        }
        $response = Invoke-WebRequest @params
        $json = if ($response.Content) {
            ConvertFrom-Json $response.Content -NoEnumerate
        } else { $null }
        [pscustomobject]@{
            Status=[int]$response.StatusCode
            Json=$json
            Range=($response.Headers['Content-Range'] -join ',')
        }
    }
    catch {
        throw 'F6 transport/JSON failure; response bodies, identities, and credentials were not logged.'
    }
}

function Assert-Status($Response, [int[]]$Expected, [string]$Label) {
    if ($Response.Status -notin $Expected) {
        $code = if ($Response.Json.code -match '^[a-zA-Z0-9_]+$') {
            $Response.Json.code
        } else { 'unavailable' }
        throw "$Label failed: HTTP $($Response.Status), code=$code."
    }
}

function Assert-BusinessError(
    $Response,
    [int[]]$ExpectedStatus,
    [string]$ExpectedCode,
    [string]$ExpectedMessage,
    [string]$Label
) {
    if ($Response.Status -notin $ExpectedStatus -or
        [string]$Response.Json.code -ne $ExpectedCode -or
        [string]$Response.Json.message -ne $ExpectedMessage) {
        throw "$Label did not return the expected safe business error."
    }
}

function Assert-Empty($Response, [string]$Label) {
    Assert-Status $Response @(200) $Label
    if ($Response.Json -isnot [array] -or @($Response.Json).Count -ne 0) {
        throw "$Label expected an empty array."
    }
}

function Assert-One($Response, [string]$ExpectedId, [string]$Label) {
    Assert-Status $Response @(200) $Label
    if ($Response.Json -isnot [array] -or @($Response.Json).Count -ne 1 -or
        [string]$Response.Json[0].id -ne $ExpectedId) {
        throw "$Label expected exactly one matching public profile."
    }
    $forbidden = @('email','phone','age','account_role','onboarding_completed')
    foreach ($field in $forbidden) {
        if ($Response.Json[0].PSObject.Properties.Name -contains $field) {
            throw "$Label exposed private profile field: $field."
        }
    }
}

function Count-Rows([string]$Table) {
    $response = Request HEAD "/rest/v1/$Table`?select=*&limit=0" $adminHeaders
    Assert-Status $response @(200,206) "Baseline count $Table"
    if ($response.Range -notmatch '/([0-9]+)$') {
        throw "Exact baseline count unavailable for $Table."
    }
    [int]$Matches[1]
}

function Get-Fixtures {
    $found = [Collections.Generic.List[object]]::new()
    for ($page=1; $page -le 20; $page++) {
        $response = Request GET "/auth/v1/admin/users?page=$page&per_page=100" $adminHeaders
        Assert-Status $response @(200) 'Fixture inventory'
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

function Send-Frame($Connection, [string]$Event, [object]$Payload, [string]$Reference) {
    $frame = @{
        topic=$Connection.Topic; event=$Event; payload=$Payload
        ref=$Reference; join_ref='1'
    } | ConvertTo-Json -Depth 12 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($frame)
    $deadline = [Threading.CancellationTokenSource]::new(10000)
    try {
        $null = $Connection.Socket.SendAsync(
            [ArraySegment[byte]]::new($bytes),
            [Net.WebSockets.WebSocketMessageType]::Text,
            $true,
            $deadline.Token
        ).GetAwaiter().GetResult()
    }
    catch { throw 'F6 Realtime send failed; frame and credentials were not logged.' }
    finally { $deadline.Dispose() }
}

function Pump($Connection) {
    if ([DateTime]::UtcNow -ge $Connection.NextHeartbeat) {
        Send-Frame $Connection heartbeat @{} ([guid]::NewGuid().ToString('N'))
        $Connection.NextHeartbeat = [DateTime]::UtcNow.AddSeconds(15)
    }
    if ($null -eq $Connection.Pending) {
        $Connection.Pending = $Connection.Socket.ReceiveAsync(
            [ArraySegment[byte]]::new($Connection.Buffer),
            [Threading.CancellationToken]::None
        )
    }
    if (-not $Connection.Pending.Wait(20)) { return }
    try { $result = $Connection.Pending.GetAwaiter().GetResult() }
    catch { throw 'F6 Realtime receive failed; payload was not logged.' }
    $Connection.Pending = $null
    if ($result.MessageType -ne [Net.WebSockets.WebSocketMessageType]::Text) {
        throw 'Unexpected F6 Realtime frame type or closed socket.'
    }
    $Connection.Stream.Write($Connection.Buffer, 0, $result.Count)
    if ($Connection.Stream.Length -gt 262144) {
        throw 'F6 Realtime frame exceeded safe test limit.'
    }
    if (-not $result.EndOfMessage) { return }
    try {
        $frame = ConvertFrom-Json ([Text.Encoding]::UTF8.GetString($Connection.Stream.ToArray()))
    }
    catch { throw 'F6 Realtime JSON invalid; frame was not logged.' }
    $Connection.Stream.SetLength(0)
    if ($frame.event -eq 'phx_reply' -and $frame.ref -eq '1') {
        if ($frame.payload.status -ne 'ok' -or
            @($frame.payload.response.postgres_changes).Count -ne 1) {
            throw 'F6 Realtime join rejected or friends subscription missing.'
        }
        $Connection.Joined = $true
    }
    elseif ($frame.event -eq 'system' -and
        $frame.payload.extension -eq 'postgres_changes') {
        if ($frame.payload.status -ne 'ok') {
            throw 'F6 Realtime Postgres subscription failed.'
        }
        $Connection.Ready = $true
    }
    elseif ($frame.event -in @('phx_error','phx_close')) {
        throw 'F6 Realtime channel failed or closed.'
    }
    elseif ($frame.event -eq 'postgres_changes') {
        $Connection.Events.Add($frame.payload.data)
    }
}

function Wait-Realtime([scriptblock]$Condition, [string]$Label, [int]$Seconds=20) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    do {
        foreach ($connection in $sockets) { Pump $connection }
        if (& $Condition) { return }
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "$Label timed out."
}

function Has-FriendEvent($Connection, [string]$UserId, [string]$FriendId, [string]$Status) {
    @($Connection.Events | Where-Object {
        $_.table -eq 'friends' -and
        [string]$_.record.user_id -eq $UserId -and
        [string]$_.record.friend_id -eq $FriendId -and
        [string]$_.record.status -eq $Status
    }).Count -gt 0
}

Push-Location $repoRoot
try {
    $projectsText = (& npx.cmd supabase projects list --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to verify Staging.' }
    $project = @(ConvertFrom-Json $projectsText | Where-Object { $_.ref -eq $stagingRef })
    if ($project.Count -ne 1 -or $project[0].name -ne $stagingName -or
        $project[0].status -ne 'ACTIVE_HEALTHY' -or -not $project[0].linked) {
        throw 'Refusing F6 E2E: unexpected linked Staging.'
    }

    $historyText = (& npx.cmd supabase migration list --project-ref $stagingRef | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to verify migration history.' }
    $migrationMatches = @{}
    try {
        $history = ConvertFrom-Json $historyText
        foreach ($version in $migrationVersions) {
            $migrationMatches[$version] = @($history.migrations | Where-Object {
                [string]$_.local -eq $version -and
                [string]$_.remote -eq $version
            }).Count
        }
    }
    catch {
        foreach ($version in $migrationVersions) {
            $migrationMatches[$version] = @([regex]::Matches(
                $historyText,
                "(?m)^\s*$version\s+\|\s+$version\s+\|"
            )).Count
        }
    }
    foreach ($version in $migrationVersions) {
        if ($migrationMatches[$version] -ne 1) {
            throw 'An F6 migration is not applied exactly once on Staging.'
        }
    }
    $dryRunText = (& npx.cmd supabase db push --linked --dry-run 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -or $dryRunText -notmatch 'Remote database is up to date') {
        throw 'Staging migration dry-run is not clean after F6 apply.'
    }
    $checks.Add('exact_staging_guard_migration_once_and_dry_run_clean')

    $keysText = (& npx.cmd supabase projects api-keys --project-ref $stagingRef --reveal --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to obtain Staging credentials.' }
    $keys = @(ConvertFrom-Json $keysText)
    $public = @($keys | Where-Object {
        $_.type -eq 'publishable' -or $_.name -eq 'anon' -or $_.id -eq 'anon'
    } | Select-Object -First 1)
    $admin = @($keys | Where-Object { $_.type -eq 'secret' } | Select-Object -First 1)
    if ($admin.Count -eq 0) {
        $admin = @($keys | Where-Object {
            $_.name -eq 'service_role' -or $_.id -eq 'service_role'
        } | Select-Object -First 1)
    }
    if ($public.Count -ne 1 -or $admin.Count -ne 1) {
        throw 'Required Staging keys missing.'
    }
    $publicValue = if ($public[0].api_key) { $public[0].api_key } else { $public[0].key }
    $adminValue = if ($admin[0].api_key) { $admin[0].api_key } else { $admin[0].key }
    if (-not $publicValue -or -not $adminValue) { throw 'Unsupported credential shape.' }
    $anonHeaders = @{
        apikey=$publicValue; 'User-Agent'='capy-f6-e2e/1.0'
    }
    $adminHeaders = @{
        apikey=$adminValue; Authorization="Bearer $adminValue"
        Prefer='return=representation,count=exact'; 'User-Agent'='capy-f6-e2e/1.0'
    }

    foreach ($table in $baselineTables) { $baseline[$table] = Count-Rows $table }

    for ($index=0; $index -lt 3; $index++) {
        $email = "f6-$runId-$index@example.com"
        $password = 'F6!' + [guid]::NewGuid().ToString('N')
        $created = Request POST '/auth/v1/admin/users' $adminHeaders @{
            email=$email; password=$password; email_confirm=$true
            user_metadata=@{test_scope=$scope; run_id=$runId}
        }
        Assert-Status $created @(200,201) 'Fixture creation'
        $id = [string]$created.Json.id
        if ($id -notmatch '^[0-9a-f-]{36}$') { throw 'Fixture identity missing.' }
        $null = $fixtureIds.Add($id)
        $login = Request POST '/auth/v1/token?grant_type=password' $anonHeaders @{
            email=$email; password=$password
        }
        Assert-Status $login @(200) 'Fixture sign-in'
        if ($login.Json.user.id -ne $id -or -not $login.Json.access_token) {
            throw 'Fixture session mismatch.'
        }
        $owner = @{
            apikey=$publicValue; Authorization="Bearer $($login.Json.access_token)"
            Prefer='return=representation'; 'User-Agent'='capy-f6-e2e/1.0'
        }
        $username = 'f6' + $runId.Substring(0,15) + $index
        $completed = Request POST '/rest/v1/rpc/complete_onboarding' $owner @{
            p_display_name="F6 fixture $index"; p_username=$username
            p_age=25; p_phone=''; p_account_role='personal'
            p_reminder_time='22:00'; p_study_end_time='02:00'; p_daily_target_words=10
            p_native_language_code='vi'; p_learning_language_code='en'
            p_proficiency_level='beginner'
        }
        Assert-Status $completed @(200) 'Fixture onboarding'
        if ($completed.Json -ne $true) { throw 'Fixture onboarding incomplete.' }
        $profile = Request GET '/rest/v1/users?select=id,email,phone' $owner
        Assert-Status $profile @(200) 'Fixture profile verification'
        if (@($profile.Json).Count -ne 1 -or
            [string]$profile.Json[0].id -ne $id -or
            [string]$profile.Json[0].email -ne $email -or
            -not [string]::IsNullOrEmpty([string]$profile.Json[0].phone)) {
            throw 'Fixture profile does not match the verified email-only Auth account.'
        }
        $accounts.Add([pscustomobject]@{
            Id=$id; Email=$email; Username=$username
            Headers=$owner; Token=$login.Json.access_token
        })
    }
    $a=$accounts[0]; $b=$accounts[1]; $c=$accounts[2]
    $checks.Add('three_verified_synthetic_accounts_onboarded')

    foreach ($account in $accounts) {
        $settings = Request POST '/rest/v1/rpc/get_my_friend_discovery_settings' $account.Headers @{}
        Assert-Status $settings @(200) 'Default discovery settings'
        if (@($settings.Json).Count -ne 1 -or
            $settings.Json[0].discoverable_by_email -ne $false -or
            $settings.Json[0].discoverable_by_phone -ne $false -or
            $settings.Json[0].email_confirmed -ne $true -or
            $settings.Json[0].phone_verified -ne $false) {
            throw 'Discovery settings did not default to private.'
        }
    }
    $byUsername = Request POST '/rest/v1/rpc/search_friend' $a.Headers @{
        p_method='username'; p_query=$b.Username.ToUpperInvariant()
    }
    Assert-One $byUsername $b.Id 'Username discovery'
    Assert-BusinessError (Request POST '/rest/v1/rpc/search_friend' $a.Headers @{
        p_method='email'; p_query=$b.Email
    }) @(400) '22023' 'invalid_search_method' 'Email discovery disabled'
    Assert-BusinessError (Request POST '/rest/v1/rpc/search_friend' $a.Headers @{
        p_method='phone'; p_query='+84912345678'
    }) @(400) '22023' 'invalid_search_method' 'Phone discovery disabled'
    $checks.Add('email_only_fixtures_username_discovery_and_non_username_denial')

    foreach ($account in $accounts) {
        $connection = [pscustomobject]@{
            Socket=[Net.WebSockets.ClientWebSocket]::new()
            Buffer=[byte[]]::new(65536); Stream=[IO.MemoryStream]::new()
            Pending=$null; Joined=$false; Ready=$false
            NextHeartbeat=[DateTime]::UtcNow.AddSeconds(15)
            Events=[Collections.Generic.List[object]]::new()
            Topic="realtime:f6-$runId"
        }
        $sockets.Add($connection)
        $deadline = [Threading.CancellationTokenSource]::new(15000)
        try {
            $uri = [uri]("wss://$stagingRef.supabase.co/realtime/v1/websocket?apikey=" +
                [uri]::EscapeDataString($publicValue) + '&vsn=1.0.0')
            $null = $connection.Socket.ConnectAsync($uri, $deadline.Token).GetAwaiter().GetResult()
        }
        catch { throw 'F6 Realtime connection failed; credentials and URI were not logged.' }
        finally { $deadline.Dispose() }
        $subscriptions = @(@{event='*'; schema='public'; table='friends'})
        Send-Frame $connection phx_join @{
            config=@{
                broadcast=@{ack=$false; self=$false}
                presence=@{enabled=$false}; private=$false
                postgres_changes=$subscriptions
            }
            access_token=$account.Token
        } '1'
    }
    Wait-Realtime {
        @($sockets | Where-Object { -not $_.Joined -or -not $_.Ready }).Count -eq 0
    } 'Friends subscriptions'
    $checks.Add('three_real_websocket_friend_subscriptions_ready')

    Assert-Status (Request POST '/rest/v1/rpc/send_friend_request' $a.Headers @{
        p_target_user_id=$a.Id
    }) @(400) 'Self request denial'
    Assert-Status (Request POST '/rest/v1/rpc/open_direct_chat' $a.Headers @{
        p_peer_id=$b.Id
    }) @(403) 'Stranger chat denial'
    $sent = Request POST '/rest/v1/rpc/send_friend_request' $a.Headers @{
        p_target_user_id=$b.Id
    }
    Assert-Status $sent @(200) 'Friend request send'
    if ($sent.Json -ne 'outgoing_pending') { throw 'Friend request state mismatch.' }
    $retry = Request POST '/rest/v1/rpc/send_friend_request' $a.Headers @{
        p_target_user_id=$b.Id
    }
    Assert-Status $retry @(200) 'Friend request retry'
    if ($retry.Json -ne 'outgoing_pending') { throw 'Friend request retry was not idempotent.' }
    Wait-Realtime {
        (Has-FriendEvent $sockets[0] $a.Id $b.Id 'pending') -and
        (Has-FriendEvent $sockets[1] $a.Id $b.Id 'pending')
    } 'Pending friend A/B relay'
    $watchUntil = [DateTime]::UtcNow.AddSeconds(2)
    while ([DateTime]::UtcNow -lt $watchUntil) { foreach ($connection in $sockets) { Pump $connection } }
    if ($sockets[2].Events.Count -ne 0) { throw 'Outsider received A/B friend Realtime data.' }

    $outgoing = Request POST '/rest/v1/rpc/list_friend_requests' $a.Headers @{
        p_direction='outgoing'; p_limit=30
    }
    $incoming = Request POST '/rest/v1/rpc/list_friend_requests' $b.Headers @{
        p_direction='incoming'; p_limit=30
    }
    Assert-Status $outgoing @(200) 'Outgoing request list'
    Assert-Status $incoming @(200) 'Incoming request list'
    if (@($outgoing.Json).Count -ne 1 -or $outgoing.Json[0].peer_id -ne $b.Id -or
        @($incoming.Json).Count -ne 1 -or $incoming.Json[0].peer_id -ne $a.Id) {
        throw 'Pending request direction mismatch.'
    }
    Assert-Empty (Request POST '/rest/v1/rpc/list_friend_requests' $c.Headers @{
        p_direction='incoming'; p_limit=30
    }) 'Outsider pending list'
    Assert-BusinessError (Request POST '/rest/v1/rpc/respond_friend_request' $c.Headers @{
        p_requester_id=$a.Id; p_decision='accept'
    }) @(500) 'P0002' 'stale_request' 'Forged acceptance denial'
    Assert-Status (Request POST '/rest/v1/rpc/open_direct_chat' $a.Headers @{
        p_peer_id=$b.Id
    }) @(403) 'Pending chat denial'
    $accepted = Request POST '/rest/v1/rpc/respond_friend_request' $b.Headers @{
        p_requester_id=$a.Id; p_decision='accept'
    }
    Assert-Status $accepted @(200) 'Friend request acceptance'
    if ($accepted.Json -ne 'accepted') { throw 'Friend acceptance state mismatch.' }
    Wait-Realtime {
        (Has-FriendEvent $sockets[0] $a.Id $b.Id 'accepted') -and
        (Has-FriendEvent $sockets[0] $b.Id $a.Id 'accepted') -and
        (Has-FriendEvent $sockets[1] $a.Id $b.Id 'accepted') -and
        (Has-FriendEvent $sockets[1] $b.Id $a.Id 'accepted')
    } 'Accepted friend A/B relay'
    $checks.Add('self_forgery_and_stranger_pending_chat_denied_idempotent_realtime_request')

    foreach ($pair in @(@($a,$b), @($b,$a))) {
        $acceptedList = Request POST '/rest/v1/rpc/list_accepted_friends' $pair[0].Headers @{
            p_limit=30
        }
        Assert-Status $acceptedList @(200) 'Accepted friends list'
        if (@($acceptedList.Json).Count -ne 1 -or
            $acceptedList.Json[0].peer_id -ne $pair[1].Id) {
            throw 'Accepted relationship is not symmetric.'
        }
    }
    Assert-Empty (Request POST '/rest/v1/rpc/list_accepted_friends' $c.Headers @{
        p_limit=30
    }) 'Outsider accepted list'
    $opened = Request POST '/rest/v1/rpc/open_direct_chat' $a.Headers @{p_peer_id=$b.Id}
    Assert-Status $opened @(200) 'Accepted direct chat'
    $conversationId = [string]$opened.Json
    if ($conversationId -notmatch '^[0-9a-f-]{36}$') { throw 'Conversation identity missing.' }
    $reopened = Request POST '/rest/v1/rpc/open_direct_chat' $b.Headers @{p_peer_id=$a.Id}
    Assert-Status $reopened @(200) 'Reversed accepted direct chat'
    if ([string]$reopened.Json -ne $conversationId) { throw 'Direct chat is not canonical.' }
    Assert-Empty (Request GET "/rest/v1/chat_conversations?id=eq.$conversationId&select=id" $c.Headers) 'Outsider chat read'
    $checks.Add('accepted_lists_symmetric_and_canonical_chat_authorized')

    $rejectedSent = Request POST '/rest/v1/rpc/send_friend_request' $a.Headers @{
        p_target_user_id=$c.Id
    }
    Assert-Status $rejectedSent @(200) 'Reject-path request send'
    $rejected = Request POST '/rest/v1/rpc/respond_friend_request' $c.Headers @{
        p_requester_id=$a.Id; p_decision='reject'
    }
    Assert-Status $rejected @(200) 'Friend request rejection'
    if ($rejected.Json -ne 'rejected') { throw 'Friend rejection state mismatch.' }
    Assert-Empty (Request POST '/rest/v1/rpc/list_accepted_friends' $c.Headers @{
        p_limit=30
    }) 'Rejected relationship accepted list'
    Assert-Status (Request POST '/rest/v1/rpc/open_direct_chat' $a.Headers @{
        p_peer_id=$c.Id
    }) @(403) 'Rejected chat denial'
    $rejectedSearch = Request POST '/rest/v1/rpc/search_friend' $a.Headers @{
        p_method='username'; p_query=$c.Username
    }
    Assert-One $rejectedSearch $c.Id 'Rejected relationship search'
    if ($rejectedSearch.Json[0].relationship_state -ne 'rejected') {
        throw 'Rejected relationship state missing from search.'
    }
    $checks.Add('reject_path_remains_non_friend_and_chat_denied')
}
finally {
    foreach ($connection in $sockets) {
        $connection.Socket.Abort(); $connection.Socket.Dispose()
        $connection.Stream.Dispose(); $connection.Events.Clear()
    }
    try {
        if ($adminHeaders) {
            foreach ($fixture in @(Get-Fixtures)) {
                $null = $fixtureIds.Add([string]$fixture.id)
            }
            foreach ($id in $fixtureIds) {
                $fixture = Request GET "/auth/v1/admin/users/$id" $adminHeaders
                Assert-Status $fixture @(200) 'Cleanup identity check'
                if ($fixture.Json.user_metadata.test_scope -ne $scope -or
                    $fixture.Json.user_metadata.run_id -ne $runId) {
                    throw 'Refusing cleanup outside exact fixture scope/run.'
                }
                Assert-Status (Request DELETE "/auth/v1/admin/users/$id" $adminHeaders) @(200,204) 'Fixture deletion'
            }
            if (@(Get-Fixtures).Count -ne 0) { throw 'Fixture Auth cleanup incomplete.' }
            if ($conversationId) {
                Assert-Empty (Request GET "/rest/v1/chat_conversations?id=eq.$conversationId&select=id" $adminHeaders) 'Conversation cascade cleanup'
            }
            foreach ($table in $baseline.Keys) {
                if ((Count-Rows $table) -ne $baseline[$table]) {
                    throw "Baseline count changed or fixture cleanup failed: $table."
                }
            }
            $checks.Add('exact_scope_auth_profile_friend_chat_cleanup_baselines_preserved')
        }
    }
    finally {
        $keysText=$null; $keys=$null; $public=$null; $admin=$null
        $publicValue=$null; $adminValue=$null; $password=$null
        $anonHeaders=$null; $adminHeaders=$null; $login=$null; $owner=$null
        $a=$null; $b=$null; $c=$null; $uri=$null
        $accounts.Clear(); $sockets.Clear()
        Pop-Location
    }
}

[pscustomobject]@{
    status='VERIFIED'; project_ref=$stagingRef; migrations=$migrationVersions
    checks=$checks.ToArray(); fixture_count_remaining=0
    production_writes=0; training_writes=0; library_writes=0
} | ConvertTo-Json -Depth 4
