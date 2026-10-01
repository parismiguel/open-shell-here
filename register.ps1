# Registers this extension with VS Code WITHOUT using the Marketplace.
#
# Useful on machines that cannot reach the Marketplace, or for testing local
# changes. Normal users should just install from the Marketplace instead.
#
# Why this script exists: copying the extension FOLDER into
# ~/.vscode/extensions is not enough. VS Code only discovers extensions listed
# in extensions.json, so a hand-copied folder is invisible until it has a
# registry entry. This script adds that entry.
#
# Close VS Code FIRST. It rewrites extensions.json on shutdown and would
# discard the change.

[CmdletBinding()]
param(
    [string] $Publisher = '',
    [switch] $Force
)

$ErrorActionPreference = 'Stop'

# Path-independent: works no matter where this repository is cloned.
$source    = $PSScriptRoot
$manifest  = Get-Content (Join-Path $source 'package.json') -Raw | ConvertFrom-Json
$name      = $manifest.name
$version   = $manifest.version
if ([string]::IsNullOrWhiteSpace($Publisher)) {
    $Publisher = $manifest.publisher
}

$id        = "$Publisher.$name"
$extRoot   = Join-Path $env:USERPROFILE '.vscode\extensions'
$target    = Join-Path $extRoot "$id-$version"
$registry  = Join-Path $extRoot 'extensions.json'

if ($id -like 'REPLACE_*' -or $id -like '*REPLACE_WITH_YOUR_PUBLISHER_ID*') {
    Write-Error "Publisher id is still the placeholder. Pass -Publisher <your-id> or edit package.json first."
    exit 1
}

# --- 1. Ensure VS Code is closed ---------------------------------------------
if (-not $Force -and (Get-Process -Name 'Code' -ErrorAction SilentlyContinue)) {
    Write-Warning 'VS Code is running. Close it fully (File > Exit) and re-run, or pass -Force.'
    Write-Warning 'VS Code rewrites extensions.json on shutdown and would discard the change.'
    exit 2
}

# --- 2. Copy the extension files, minus the dev-only scripts ------------------
if (Test-Path $target) {
    Remove-Item $target -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $target | Out-Null

Get-ChildItem $source -File | Where-Object { $_.Extension -ne '.ps1' } | ForEach-Object {
    Copy-Item $_.FullName -Destination $target -Force
}

Write-Host "Copied extension files to $target" -ForegroundColor Green

# --- 3. Back up the registry -------------------------------------------------
if (Test-Path $registry) {
    Copy-Item $registry "$registry.bak" -Force
    Write-Host 'Backed up extensions.json -> extensions.json.bak'
}
else {
    '[]' | Set-Content $registry -Encoding UTF8
    Write-Host 'Created a new extensions.json'
}

# --- 4. Add or refresh the registry entry ------------------------------------
$all = @(Get-Content $registry -Raw | ConvertFrom-Json)
$all = @($all | Where-Object { $_.identifier.id -ne $id })

$entry = [PSCustomObject]@{
    identifier       = [PSCustomObject]@{ id = $id; uuid = $null }
    version          = $version
    location         = [PSCustomObject]@{
        '$mid' = 1
        path   = "/c:/$($target -replace '\\', '/')"
        scheme = 'file'
    }
    relativeLocation = "$id-$version"
    metadata         = [PSCustomObject]@{
        installedTimestamp   = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        pinned               = $false
        source               = '$extensionDevelopmentPath'
        id                   = $null
        publisherId          = $null
        publisherDisplayName = $null
        targetPlatform       = 'undefined'
        updated              = $false
        private              = $false
        isPreReleaseVersion  = $false
        hasPreReleaseVersion = $false
    }
}

$all = @($all) + $entry

$json = ConvertTo-Json -InputObject $all -Depth 10 -Compress
[System.IO.File]::WriteAllText($registry, $json, (New-Object System.Text.UTF8Encoding $false))

Write-Host "Registered $id@$version" -ForegroundColor Green
Write-Host "Total extensions registered: $($all.Count)"
Write-Host ''
Write-Host 'Start VS Code, then run "Developer: Reload Window".' -ForegroundColor Green