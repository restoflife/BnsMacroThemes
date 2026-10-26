[CmdletBinding()]
param(
    [switch]$NoVersionBump,
    [switch]$MarkPublished
)

$ErrorActionPreference = 'Stop'
Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop

if ($NoVersionBump -and $MarkPublished) {
    throw 'NoVersionBump 与 MarkPublished 不能同时使用。'
}

function Get-NextVersion {
    param([string]$CurrentVersion)

    $number = 0
    if ([int]::TryParse($CurrentVersion, [ref]$number)) {
        return ($number + 1).ToString()
    }

    return [DateTimeOffset]::UtcNow.ToString('yyyyMMddHHmmss')
}

function Get-ManifestFileSignature {
    param($Files)

    if ($null -eq $Files) {
        return ''
    }

    return (($Files | ForEach-Object {
        '{0}|{1}|{2}' -f ([string]$_.name), ([string]$_.url), ([string]$_.sha256).ToUpperInvariant()
    }) -join "`n")
}

function Write-JsonFile {
    param(
        [string]$Path,
        $Value
    )

    $json = $Value | ConvertTo-Json -Depth 8
    $tempPath = $Path + '.tmp'
    [IO.File]::WriteAllText($tempPath, $json + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
    $null = Get-Content -LiteralPath $tempPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Move-Item -LiteralPath $tempPath -Destination $Path -Force
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$themesRoot = Join-Path $scriptRoot 'themes'
$catalogPath = Join-Path $themesRoot 'catalog.json'
$publishedVersionsPath = Join-Path $scriptRoot 'published-versions.json'

if (-not (Test-Path -LiteralPath $themesRoot -PathType Container)) {
    throw "没有找到主题目录：$themesRoot"
}

if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
    throw "没有找到主题目录清单：$catalogPath"
}

$catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
$oldCatalogSignature = $catalog | ConvertTo-Json -Depth 8 -Compress
$catalogById = @{}

foreach ($entry in @($catalog.themes)) {
    $catalogById[[string]$entry.id] = $entry
}

if (Test-Path -LiteralPath $publishedVersionsPath -PathType Leaf) {
    $publishedVersions = Get-Content -LiteralPath $publishedVersionsPath -Raw -Encoding UTF8 | ConvertFrom-Json
}
else {
    $initialThemeVersions = [ordered]@{}
    foreach ($entry in @($catalog.themes)) {
        $initialThemeVersions[[string]$entry.id] = [string]$entry.version
    }

    $publishedVersions = [ordered]@{
        catalogVersion = [string]$catalog.version
        themeVersions  = $initialThemeVersions
    }
    Write-JsonFile -Path $publishedVersionsPath -Value $publishedVersions
    $publishedVersions = Get-Content -LiteralPath $publishedVersionsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "已按当前清单创建已发布版本基线：$publishedVersionsPath" -ForegroundColor Yellow
}

if ([string]::IsNullOrWhiteSpace([string]$publishedVersions.catalogVersion) -or
    $null -eq $publishedVersions.themeVersions) {
    throw "已发布版本基线缺少 catalogVersion 或 themeVersions：$publishedVersionsPath"
}

function Get-PublishedThemeVersion {
    param([string]$ThemeId)

    $property = $publishedVersions.themeVersions.PSObject.Properties[$ThemeId]
    if ($null -eq $property -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
        return '0'
    }

    return [string]$property.Value
}

$themeResults = New-Object System.Collections.Generic.List[object]
$generatedCatalogEntries = New-Object System.Collections.Generic.List[object]
$themeDirectories = @(Get-ChildItem -LiteralPath $themesRoot -Directory | Sort-Object Name)

foreach ($directory in $themeDirectories) {
    $manifestPath = Join-Path $directory.FullName 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "没有找到主题清单：$manifestPath"
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace([string]$manifest.id) -or
        [string]::IsNullOrWhiteSpace([string]$manifest.name) -or
        [string]::IsNullOrWhiteSpace([string]$manifest.version)) {
        throw "主题清单缺少 id、name 或 version：$manifestPath"
    }

    $images = @(Get-ChildItem -LiteralPath $directory.FullName -Filter '*.jpg' -File | Sort-Object Name)
    if ($images.Count -lt 1 -or $images.Count -gt 25) {
        throw "每个主题必须包含 1 到 25 张 JPG 图片：$($directory.FullName)"
    }

    $files = @(
        foreach ($image in $images) {
            [ordered]@{
                name   = $image.Name
                url    = $image.Name
                sha256 = (Get-FileHash -LiteralPath $image.FullName -Algorithm SHA256).Hash.ToUpperInvariant()
            }
        }
    )

    $oldSignature = Get-ManifestFileSignature -Files @($manifest.files)
    $newSignature = Get-ManifestFileSignature -Files $files
    $contentChanged = $oldSignature -cne $newSignature
    $oldVersion = [string]$manifest.version
    $newVersion = $oldVersion
    $publishedVersion = Get-PublishedThemeVersion -ThemeId ([string]$manifest.id)

    if ($contentChanged -and -not $NoVersionBump) {
        # 未发布期间无论图片修改多少次，都固定使用“已发布版本 + 1”。
        $newVersion = Get-NextVersion -CurrentVersion $publishedVersion
    }

    $newManifest = [ordered]@{
        id      = [string]$manifest.id
        name    = [string]$manifest.name
        version = $newVersion
        files   = $files
    }
    Write-JsonFile -Path $manifestPath -Value $newManifest

    $existingEntry = $catalogById[[string]$manifest.id]
    $description = if ($null -ne $existingEntry -and $null -ne $existingEntry.description) {
        [string]$existingEntry.description
    }
    else {
        ([string]$manifest.name) + '主题'
    }

    $generatedCatalogEntries.Add([ordered]@{
        id          = [string]$manifest.id
        name        = [string]$manifest.name
        version     = $newVersion
        description = $description
        imageCount  = $images.Count
        manifest    = $directory.Name + '/manifest.json'
    })

    $themeResults.Add([PSCustomObject]@{
        Id             = [string]$manifest.id
        Name           = [string]$manifest.name
        Images         = $images.Count
        ContentChanged = $contentChanged
        PublishedVersion = $publishedVersion
        OldVersion     = $oldVersion
        NewVersion     = $newVersion
    })
}

$existingIds = @($themeDirectories | ForEach-Object { $_.Name })
$removedCatalogEntries = @($catalog.themes | Where-Object {
    $manifestRelativePath = [string]$_.manifest
    $themeFolder = ($manifestRelativePath -split '[/\\]')[0]
    $existingIds -notcontains $themeFolder
})

# Preserve the existing catalog order so regenerating hashes does not reorder the UI.
# Newly added theme directories are appended after all existing entries.
$newCatalogEntries = New-Object System.Collections.Generic.List[object]
$addedIds = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

foreach ($oldEntry in @($catalog.themes)) {
    $matchedEntry = $generatedCatalogEntries | Where-Object {
        ([string]$_.id).Equals([string]$oldEntry.id, [StringComparison]::OrdinalIgnoreCase)
    } | Select-Object -First 1
    if ($null -ne $matchedEntry) {
        $newCatalogEntries.Add($matchedEntry)
        $null = $addedIds.Add([string]$matchedEntry.id)
    }
}

foreach ($generatedEntry in $generatedCatalogEntries) {
    if ($addedIds.Add([string]$generatedEntry.id)) {
        $newCatalogEntries.Add($generatedEntry)
    }
}

$candidateCatalog = [ordered]@{
    version = [string]$catalog.version
    themes  = $newCatalogEntries.ToArray()
}
$candidateSignature = $candidateCatalog | ConvertTo-Json -Depth 8 -Compress
$catalogChanged = $oldCatalogSignature -cne $candidateSignature

if ($catalogChanged -and -not $NoVersionBump) {
    # 目录版本同样只占用“已发布版本 + 1”，重复生成不会继续递增。
    $candidateCatalog.version = Get-NextVersion -CurrentVersion ([string]$publishedVersions.catalogVersion)
}

Write-JsonFile -Path $catalogPath -Value $candidateCatalog

if ($MarkPublished) {
    $publishedThemeVersions = [ordered]@{}
    foreach ($entry in $newCatalogEntries) {
        $publishedThemeVersions[[string]$entry.id] = [string]$entry.version
    }

    $publishedVersions = [ordered]@{
        catalogVersion = [string]$candidateCatalog.version
        themeVersions  = $publishedThemeVersions
    }
    Write-JsonFile -Path $publishedVersionsPath -Value $publishedVersions
}

Write-Host ''
Write-Host '全部主题清单已重新生成。' -ForegroundColor Green
$themeResults |
    Select-Object @{Name = '主题ID'; Expression = { $_.Id } },
        @{Name = '主题名称'; Expression = { $_.Name } },
        @{Name = '图片数'; Expression = { $_.Images } },
        @{Name = '内容变化'; Expression = { $_.ContentChanged } },
        @{Name = '已发布版本'; Expression = { $_.PublishedVersion } },
        @{Name = '原版本'; Expression = { $_.OldVersion } },
        @{Name = '新版本'; Expression = { $_.NewVersion } } |
    Format-Table -AutoSize

if ($removedCatalogEntries.Count -gt 0) {
    Write-Host ''
    Write-Host '以下主题目录已删除，并已从 catalog.json 移除：' -ForegroundColor Yellow
    $removedCatalogEntries | ForEach-Object { Write-Host ('  - ' + [string]$_.id) }
}

Write-Host ''
Write-Host "目录清单：$catalogPath"
Write-Host "目录版本：$($candidateCatalog.version)"
Write-Host "主题数量：$($newCatalogEntries.Count)"
Write-Host "已发布版本基线：$publishedVersionsPath"
if ($MarkPublished) {
    Write-Host '当前目录和主题版本已标记为已发布基线。' -ForegroundColor Cyan
}
