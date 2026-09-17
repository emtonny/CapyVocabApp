#requires -Version 7.0
# Read-only inventory. Never prints message contents, user IDs or API keys.
$ErrorActionPreference = 'Stop'
$stagingRef = 'nxteaznowkfennxpqjmt'
$baseUrl = "https://$stagingRef.supabase.co"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $repoRoot
try {
    $projectsText = (& npx.cmd supabase projects list --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to verify Staging target.' }
    $project = @(ConvertFrom-Json $projectsText | Where-Object { $_.ref -eq $stagingRef })
    if ($project.Count -ne 1 -or $project[0].name -ne "emtonny's Project" -or
        $project[0].status -ne 'ACTIVE_HEALTHY' -or -not $project[0].linked) { throw 'Unexpected linked Staging target.' }
    $keysText = (& npx.cmd supabase projects api-keys --project-ref $stagingRef --reveal --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to obtain read-only audit credential.' }
    $keys = @(ConvertFrom-Json $keysText)
    $credential = @($keys | Where-Object { $_.type -eq 'secret' } | Select-Object -First 1)
    if ($credential.Count -eq 0) {
        $credential = @($keys | Where-Object { $_.name -eq 'service_role' -or $_.id -eq 'service_role' } | Select-Object -First 1)
    }
    if ($credential.Count -ne 1) { throw 'Required audit credential unavailable.' }
    $keyValue = if ($credential[0].api_key) { $credential[0].api_key } else { $credential[0].key }
    if (-not $keyValue) { throw 'Unsupported audit credential shape.' }
    $headers = @{apikey=$keyValue; Authorization="Bearer $keyValue"; Prefer='count=exact'; 'User-Agent'='capy-c2-readonly-audit/1.0'}
    $legacy = Invoke-WebRequest -Method Head -Uri "$baseUrl/rest/v1/chat_messages?select=id,user_id,message,is_ai_response,timestamp&limit=0" `
        -Headers $headers -TimeoutSec 30 -SkipHttpErrorCheck
    $range = $legacy.Headers['Content-Range'] -join ','
    if ([int]$legacy.StatusCode -ne 200 -or $range -notmatch '/([0-9]+)$') { throw 'Legacy schema/count audit failed; no content was logged.' }
    $legacyCount = [int]$Matches[1]
    $response = Invoke-WebRequest -Method Get -Uri "$baseUrl/rest/v1/friends?select=user_id,friend_id,status&limit=1001" `
        -Headers $headers -TimeoutSec 30 -SkipHttpErrorCheck
    if ([int]$response.StatusCode -ne 200) { throw 'Friendship inventory failed.' }
    $friends = @(ConvertFrom-Json $response.Content)
    $friendRange = $response.Headers['Content-Range'] -join ','
    if ($friendRange -notmatch '/([0-9]+)$') { throw 'Exact friendship count unavailable; refusing incomplete inventory.' }
    $friendTotal = [int]$Matches[1]
    if ($friends.Count -gt 1000 -or $friends.Count -ne $friendTotal) {
        throw 'Friendship inventory truncated; refusing to claim completeness.'
    }
    $accepted = @($friends | Where-Object { $_.status -eq 'accepted' })
    $acceptedPairs = [Collections.Generic.HashSet[string]]::new()
    foreach ($friend in $accepted) { $null=$acceptedPairs.Add("$($friend.user_id)/$($friend.friend_id)") }
    $unpaired = @($accepted | Where-Object { -not $acceptedPairs.Contains("$($_.friend_id)/$($_.user_id)") }).Count
    [pscustomobject]@{
        status='VERIFIED'; access='READ_ONLY'; project_ref=$stagingRef
        legacy_columns_verified=$true; legacy_messages=$legacyCount
        friends=$friends.Count; accepted_directed_rows=$accepted.Count; accepted_unpaired_rows=$unpaired
        migration_decision='No backfill. Preserve legacy table/API; human chat uses chat_operational_messages.'
    } | ConvertTo-Json
}
finally {
    $headers=$null; $keyValue=$null; $credential=$null; $keys=$null; $keysText=$null; $friends=$null; $accepted=$null
    Pop-Location
}
