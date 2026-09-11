param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectName,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z]{20}$')]
    [string]$ProjectRef,

    [ValidateRange(1, 10000)]
    [int]$PageSize = 500,

    [ValidateRange(1, 100000)]
    [int]$MaximumObjects = 10000
)

$ErrorActionPreference = 'Stop'
$bucketName = 'photo_notes'
$uuidPattern = '[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}'
$normalizedPathPattern = "^(?<owner>$uuidPattern)/(?<media>$uuidPattern)/(?<variant>display|original|model_input)\.(?<extension>jpg|jpeg|png|webp|heic)$"
$legacyPathPattern = "^(?<owner>$uuidPattern)/(?<timestamp>[0-9]+)_note\.(?<extension>jpg|jpeg|png|webp|heic)$"

function Get-HttpStatusCode {
    param([System.Management.Automation.ErrorRecord]$ErrorRecord)

    $response = $ErrorRecord.Exception.Response
    if ($null -eq $response) {
        return $null
    }
    if ($response.StatusCode -is [int]) {
        return [int]$response.StatusCode
    }
    return [int]$response.StatusCode.value__
}

function Invoke-CapyReadRequest {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('GET', 'POST')]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers,

        [object]$Body,

        [switch]$AllowMissing
    )

    try {
        if ($Method -eq 'GET') {
            return Invoke-RestMethod -Method Get -Uri $Uri -Headers $Headers
        }

        # Supabase Storage uses POST for its list operation. This endpoint is
        # read-only even though the transport verb is POST.
        $jsonBody = $Body | ConvertTo-Json -Depth 5 -Compress
        return Invoke-RestMethod -Method Post -Uri $Uri -Headers $Headers `
            -ContentType 'application/json' -Body $jsonBody
    }
    catch {
        $statusCode = Get-HttpStatusCode -ErrorRecord $_
        if ($AllowMissing -and $statusCode -in @(400, 404)) {
            return $null
        }
        throw
    }
}

function Get-PagedRows {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$Table,

        [Parameter(Mandatory = $true)]
        [string]$Select,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers,

        [switch]$AllowMissing
    )

    $rows = [System.Collections.Generic.List[object]]::new()
    $offset = 0
    while ($true) {
        $uri = "$BaseUrl/rest/v1/$Table`?select=$Select&limit=$PageSize&offset=$offset"
        $page = Invoke-CapyReadRequest -Method GET -Uri $uri -Headers $Headers `
            -AllowMissing:$AllowMissing
        if ($null -eq $page) {
            return [pscustomobject]@{
                Exists = $false
                Rows = @()
            }
        }
        $pageRows = @($page)
        foreach ($row in $pageRows) {
            $rows.Add($row)
        }
        if ($pageRows.Count -lt $PageSize) {
            break
        }
        $offset += $PageSize
    }
    return [pscustomobject]@{
        Exists = $true
        Rows = @($rows)
    }
}

function Resolve-LegacyObjectPath {
    param([AllowEmptyString()][string]$ImagePath)

    if ([string]::IsNullOrWhiteSpace($ImagePath)) {
        return [pscustomobject]@{ Category = 'empty'; ObjectPath = $null }
    }

    $trimmed = $ImagePath.Trim()
    $publicUrlMatch = [regex]::Match(
        $trimmed,
        '/storage/v1/object/public/photo_notes/(?<path>[^?#]+)',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    if ($publicUrlMatch.Success) {
        return [pscustomobject]@{
            Category = 'public_url'
            ObjectPath = [System.Uri]::UnescapeDataString(
                $publicUrlMatch.Groups['path'].Value
            )
        }
    }
    if ($trimmed -match '^https?://') {
        return [pscustomobject]@{ Category = 'external_url'; ObjectPath = $null }
    }
    if ($trimmed -match $normalizedPathPattern) {
        return [pscustomobject]@{ Category = 'normalized_path'; ObjectPath = $trimmed }
    }
    if ($trimmed -match $legacyPathPattern) {
        return [pscustomobject]@{ Category = 'legacy_path'; ObjectPath = $trimmed }
    }
    return [pscustomobject]@{ Category = 'other'; ObjectPath = $trimmed }
}

function Get-StorageObjects {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    $objects = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )
    $pendingPrefixes = [System.Collections.Generic.Queue[string]]::new()
    $seenPrefixes = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )
    $pendingPrefixes.Enqueue('')
    $truncated = $false

    while ($pendingPrefixes.Count -gt 0 -and -not $truncated) {
        $prefix = $pendingPrefixes.Dequeue()
        if (-not $seenPrefixes.Add($prefix)) {
            continue
        }

        $offset = 0
        while ($true) {
            $page = Invoke-CapyReadRequest -Method POST `
                -Uri "$BaseUrl/storage/v1/object/list/$bucketName" `
                -Headers $Headers `
                -Body @{
                    prefix = $prefix
                    limit = $PageSize
                    offset = $offset
                    sortBy = @{ column = 'name'; order = 'asc' }
                }
            $entries = @($page)
            foreach ($entry in $entries) {
                $fullName = if ([string]::IsNullOrEmpty($prefix)) {
                    [string]$entry.name
                }
                else {
                    "$prefix/$($entry.name)"
                }

                if ($null -eq $entry.id) {
                    $pendingPrefixes.Enqueue($fullName)
                }
                else {
                    [void]$objects.Add($fullName)
                    if ($objects.Count -ge $MaximumObjects) {
                        $truncated = $true
                        break
                    }
                }
            }
            if ($entries.Count -lt $PageSize -or $truncated) {
                break
            }
            $offset += $PageSize
        }
    }

    return [pscustomobject]@{
        Paths = $objects
        Truncated = $truncated
        PrefixCount = $seenPrefixes.Count
    }
}

function Assert-PathClassifierContract {
    $owner = '11111111-1111-4111-8111-111111111111'
    $media = '22222222-2222-4222-8222-222222222222'
    $cases = @(
        @("$owner/$media/display.jpg", 'normalized_path'),
        @("$owner/1720000000000_note.jpg", 'legacy_path'),
        @(
            "https://example.supabase.co/storage/v1/object/public/photo_notes/$owner/1720000000000_note.jpg",
            'public_url'
        ),
        @('https://cdn.example.com/image.jpg', 'external_url'),
        @('', 'empty'),
        @('unexpected/path.jpg', 'other')
    )
    foreach ($case in $cases) {
        $actual = Resolve-LegacyObjectPath -ImagePath $case[0]
        if ($actual.Category -ne $case[1]) {
            throw "Path classifier contract failed for category $($case[1])."
        }
    }
}

Assert-PathClassifierContract

$projectsJson = (& npx.cmd supabase projects list --output json | Out-String)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to list Supabase projects.'
}
$projects = @(ConvertFrom-Json -InputObject $projectsJson)
$project = @($projects | Where-Object {
    $_.name -eq $ProjectName -and $_.ref -eq $ProjectRef
})
if ($project.Count -ne 1) {
    throw 'Refusing audit: project name/ref did not identify exactly one project.'
}
if ($project[0].status -ne 'ACTIVE_HEALTHY') {
    throw "Refusing audit: project is not ACTIVE_HEALTHY."
}

$keysJson = (& npx.cmd supabase projects api-keys `
    --project-ref $ProjectRef --output json | Out-String)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to obtain temporary project API credentials.'
}
$keys = @(ConvertFrom-Json -InputObject $keysJson)
$service = @($keys | Where-Object {
    $_.name -eq 'service_role' -or $_.id -eq 'service_role'
} | Select-Object -First 1)
if ($service.Count -ne 1) {
    throw 'Supabase CLI did not return exactly one service_role key.'
}
$serviceKey = if ($service[0].api_key) {
    $service[0].api_key
}
else {
    $service[0].key
}
if (-not $serviceKey) {
    throw 'Supabase CLI returned an unsupported service_role key shape.'
}

$baseUrl = "https://$ProjectRef.supabase.co"
$headers = @{
    apikey = $serviceKey
    Authorization = "Bearer $serviceKey"
}

try {
    $mediaAssetResult = Get-PagedRows -BaseUrl $baseUrl -Table 'media_assets' `
        -Select 'id%2Cuser_id%2Coriginal_object_path%2Cdisplay_object_path%2Cmodel_input_object_path' `
        -Headers $headers `
        -AllowMissing
    $hasMediaAssets = $mediaAssetResult.Exists
    $mediaAssets = @($mediaAssetResult.Rows)
    $photoSelect = if ($hasMediaAssets) {
        'id%2Cuser_id%2Cimage_path%2Cmedia_asset_id'
    }
    else {
        'id%2Cuser_id%2Cimage_path'
    }
    $photoNoteResult = Get-PagedRows -BaseUrl $baseUrl -Table 'photo_notes' `
        -Select $photoSelect -Headers $headers
    if (-not $photoNoteResult.Exists) {
        throw 'Required photo_notes table is missing.'
    }
    $photoNotes = @($photoNoteResult.Rows)

    $bucket = Invoke-CapyReadRequest -Method GET `
        -Uri "$baseUrl/storage/v1/bucket/$bucketName" -Headers $headers `
        -AllowMissing
    $storage = if ($null -eq $bucket) {
        [pscustomobject]@{
            Paths = [System.Collections.Generic.HashSet[string]]::new()
            Truncated = $false
            PrefixCount = 0
        }
    }
    else {
        Get-StorageObjects -BaseUrl $baseUrl -Headers $headers
    }

    $categories = @{
        public_url = 0
        external_url = 0
        normalized_path = 0
        legacy_path = 0
        other = 0
        empty = 0
    }
    $referencedObjects = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )
    $publicUrlMissingObject = 0
    foreach ($note in @($photoNotes)) {
        $resolved = Resolve-LegacyObjectPath -ImagePath ([string]$note.image_path)
        $categories[$resolved.Category] += 1
        if ($null -ne $resolved.ObjectPath) {
            [void]$referencedObjects.Add($resolved.ObjectPath)
            if ($resolved.Category -eq 'public_url' -and
                -not $storage.Paths.Contains($resolved.ObjectPath)) {
                $publicUrlMissingObject += 1
            }
        }
    }
    if ($hasMediaAssets) {
        foreach ($asset in @($mediaAssets)) {
            foreach ($objectPath in @(
                $asset.original_object_path,
                $asset.display_object_path,
                $asset.model_input_object_path
            )) {
                if (-not [string]::IsNullOrWhiteSpace([string]$objectPath)) {
                    [void]$referencedObjects.Add([string]$objectPath)
                }
            }
        }
    }

    $normalizedStorageObjects = 0
    $legacyStorageObjects = 0
    $otherStorageObjects = 0
    $unreferencedStorageObjects = 0
    foreach ($path in $storage.Paths) {
        if ($path -match $normalizedPathPattern) {
            $normalizedStorageObjects += 1
        }
        elseif ($path -match $legacyPathPattern) {
            $legacyStorageObjects += 1
        }
        else {
            $otherStorageObjects += 1
        }
        if (-not $referencedObjects.Contains($path)) {
            $unreferencedStorageObjects += 1
        }
    }

    $nullMediaAssetReferences = 0
    $missingMediaAssetRows = 0
    $mismatchedDisplayPaths = 0
    if ($hasMediaAssets) {
        $mediaIndex = @{}
        foreach ($asset in @($mediaAssets)) {
            $mediaIndex["$($asset.user_id)/$($asset.id)"] = [string]$asset.display_object_path
        }
        foreach ($note in @($photoNotes)) {
            if ($null -eq $note.media_asset_id) {
                $nullMediaAssetReferences += 1
                continue
            }
            $mediaKey = "$($note.user_id)/$($note.media_asset_id)"
            if (-not $mediaIndex.ContainsKey($mediaKey)) {
                $missingMediaAssetRows += 1
            }
            elseif ([string]$note.image_path -ne $mediaIndex[$mediaKey]) {
                $mismatchedDisplayPaths += 1
            }
        }
    }

    $legacyRows = $categories.public_url + $categories.external_url +
        $categories.legacy_path + $categories.other + $categories.empty
    $result = [ordered]@{
        audit_version = 2
        audited_at_utc = [DateTime]::UtcNow.ToString('o')
        access_mode = 'service_role_read_only'
        project = [ordered]@{
            name = $ProjectName
            ref = $ProjectRef
            status = $project[0].status
            linked = [bool]$project[0].linked
        }
        schema = [ordered]@{
            media_assets_exists = $hasMediaAssets
        }
        photo_notes = [ordered]@{
            total = @($photoNotes).Count
            public_url = $categories.public_url
            external_url = $categories.external_url
            normalized_path = $categories.normalized_path
            legacy_object_path = $categories.legacy_path
            other_path = $categories.other
            empty_path = $categories.empty
            public_url_missing_object = $publicUrlMissingObject
            null_media_asset_reference = if ($hasMediaAssets) {
                $nullMediaAssetReferences
            } else { $null }
            missing_media_asset_row = if ($hasMediaAssets) {
                $missingMediaAssetRows
            } else { $null }
            mismatched_display_path = if ($hasMediaAssets) {
                $mismatchedDisplayPaths
            } else { $null }
        }
        storage = [ordered]@{
            bucket_exists = $null -ne $bucket
            bucket_public = if ($null -ne $bucket) { [bool]$bucket.public } else { $null }
            object_count = $storage.Paths.Count
            normalized_objects = $normalizedStorageObjects
            legacy_objects = $legacyStorageObjects
            other_objects = $otherStorageObjects
            unreferenced_objects = $unreferencedStorageObjects
            prefixes_scanned = $storage.PrefixCount
            truncated = $storage.Truncated
        }
        rollout_gate = [ordered]@{
            legacy_backfill_required = $legacyRows -gt 0 -or $legacyStorageObjects -gt 0
            complete_inventory = -not $storage.Truncated
            m3a_schema_present = $hasMediaAssets
            bucket_is_private = $null -ne $bucket -and -not [bool]$bucket.public
        }
    }

    $result | ConvertTo-Json -Depth 8
}
finally {
    $serviceKey = $null
    $headers = $null
}
