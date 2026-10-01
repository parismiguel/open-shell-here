# Refreshes PATH in the CURRENT PowerShell session, then verifies the
# publishing toolchain (node / npm / vsce).
#
# Why you need this: the Node.js installer updates PATH in the registry, but
# already-open shells keep the old value. Either restart the shell, or run this.
#
# Run in the PowerShell window where "node" is not recognised:
#   .\refresh-path.ps1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

function Update-SessionPath {
    # Read the persisted values straight from the registry and merge them into
    # this process, which is what Explorer does when it starts a new shell.
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')

    $parts = @()
    foreach ($value in @($machine, $user)) {
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $parts += $value -split ';'
        }
    }

    $merged = @()
    foreach ($entry in ($parts | Where-Object { $_ -ne '' })) {
        $trimmed = $entry.TrimEnd('\')
        if (-not ($merged | Where-Object { $_.TrimEnd('\') -ieq $trimmed })) {
            $merged += $trimmed
        }
    }

    $env:Path = ($merged -join ';')
    Write-Host 'Session PATH refreshed from the registry.' -ForegroundColor Green
}

# A few common install locations, in case the installer did not register them.
$fallbacks = @(
    'C:\Program Files\nodejs',
    'C:\Program Files (x86)\nodejs',
    (Join-Path $env:LOCALAPPDATA 'Programs\nodejs')
)

function Add-IfMissing {
    param([string] $Directory)

    if (-not (Test-Path $Directory)) {
        return
    }

    if ($env:Path -split ';' | Where-Object { $_.TrimEnd('\') -ieq $Directory.TrimEnd('\') }) {
        return
    }

    $env:Path = "$Directory;$env:Path"
    Write-Host "  Added to session PATH: $Directory" -ForegroundColor Yellow
}

Write-Host 'Refreshing PATH...' -ForegroundColor Cyan
Update-SessionPath

foreach ($dir in $fallbacks) {
    Add-IfMissing -Directory $dir
}

Write-Host ''
Write-Host '== Verification ==' -ForegroundColor Cyan

$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    Write-Host ("  [OK]   node  {0}  ->  {1}" -f (node --version), $node.Source) -ForegroundColor Green
}
else {
    Write-Host '  [MISS] node still not on PATH.' -ForegroundColor Red
    Write-Host '         Search for node.exe and add its folder to PATH manually.' -ForegroundColor Red
    exit 1
}

$npm = Get-Command npm -ErrorAction SilentlyContinue
if ($npm) {
    Write-Host ("  [OK]   npm   {0}  ->  {1}" -f (npm --version), $npm.Source) -ForegroundColor Green
}
else {
    Write-Host '  [MISS] npm not found. Reinstall Node.js (it bundles npm).' -ForegroundColor Red
}

$vsce = Get-Command vsce -ErrorAction SilentlyContinue
if ($vsce) {
    Write-Host ("  [OK]   vsce  {0}  ->  {1}" -f (vsce --version), $vsce.Source) -ForegroundColor Green
}
else {
    Write-Host '  [MISS] vsce not installed. Run:  npm install -g @vscode/vsce' -ForegroundColor Yellow
    Write-Host '         Then close and reopen PowerShell, and run this script again.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'If node works but the next shell does not, PATH will be fine after a restart.' -ForegroundColor DarkGray