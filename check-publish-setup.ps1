# Checks the publishing toolchain and reports exactly what is missing.
#
# Run in an external PowerShell window:
#   .\check-publish-setup.ps1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

function Test-Tool {
    param(
        [string] $Name,
        [string] $Command,
        [string[]] $VersionArgs,
        [string] $InstallHint
    )

    Write-Host "== $Name ==" -ForegroundColor Cyan

    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Write-Host "  [MISS] '$Command' is not on PATH." -ForegroundColor Yellow
        Write-Host "         Fix: $InstallHint" -ForegroundColor Yellow
        return $false
    }

    Write-Host ("  [OK]   {0} -> {1}" -f $Command, $cmd.Source) -ForegroundColor Green

    try {
        $output = & $Command @VersionArgs 2>&1 | Select-Object -First 1
        Write-Host "         version: $output" -ForegroundColor DarkGray
    }
    catch {
        Write-Host "         (installed, but version check failed)" -ForegroundColor DarkGray
    }

    return $true
}

$nodeOk = Test-Tool -Name 'Node.js' -Command 'node' -VersionArgs @('--version') `
    -InstallHint 'Install Node.js LTS from https://nodejs.org/ - rerun after installing.'

$npmOk = Test-Tool -Name 'npm' -Command 'npm' -VersionArgs @('--version') `
    -InstallHint 'Ships with Node.js. Reinstall Node.js if missing.'

$vsceOk = Test-Tool -Name 'vsce (publishing CLI)' -Command 'vsce' -VersionArgs @('--version') `
    -InstallHint 'npm install -g @vscode/vsce'

Write-Host ''
Write-Host '== Extension manifest ==' -ForegroundColor Cyan

$manifestPath = Join-Path $PSScriptRoot 'package.json'
if (-not (Test-Path $manifestPath)) {
    Write-Host "  [MISS] package.json not found at $manifestPath" -ForegroundColor Red
}
else {
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

    if ($manifest.publisher -like 'REPLACE_*') {
        Write-Host "  [TODO] publisher is still the placeholder: '$($manifest.publisher)'" -ForegroundColor Yellow
        Write-Host '         Create one at https://marketplace.visualstudio.com/manage' -ForegroundColor Yellow
    }
    else {
        Write-Host "  [OK]   publisher: $($manifest.publisher)" -ForegroundColor Green
    }

    foreach ($required in 'README.md', 'LICENSE', 'CHANGELOG.md') {
        if (Test-Path (Join-Path $PSScriptRoot $required)) {
            Write-Host "  [OK]   $required" -ForegroundColor Green
        }
        else {
            Write-Host "  [MISS] $required" -ForegroundColor Red
        }
    }

    if ($manifest.icon) {
        $iconPath = Join-Path $PSScriptRoot $manifest.icon
        if (Test-Path $iconPath) {
            Write-Host ("  [OK]   icon: {0}" -f $manifest.icon) -ForegroundColor Green
        }
        else {
            Write-Host "  [MISS] icon '$($manifest.icon)' - run .\generate-icon.ps1" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  [WARN] no icon in the manifest - Marketplace listings look unpolished" -ForegroundColor Yellow
    }
}

Write-Host ''
if ($nodeOk -and $npmOk -and $vsceOk) {
    Write-Host 'Toolchain looks complete. Next: vsce login proyectos-innovadores-eirl' -ForegroundColor Green
}
else {
    Write-Host 'Install the missing tools listed above, then re-run this script.' -ForegroundColor Yellow
}