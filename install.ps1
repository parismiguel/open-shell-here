# Convenience wrapper: verifies the shells on this machine, then registers the
# extension. Path-independent - works from any clone location.
#
# Run in an external PowerShell window, not the VS Code integrated terminal
# (that is usually the thing that is broken on the affected systems).
#
# Usage:
#   .\install.ps1                          # uses the publisher from package.json
#   .\install.ps1 -Publisher my-publisher   # override the publisher id

[CmdletBinding()]
param(
    [string] $Publisher = ''
)

$ErrorActionPreference = 'Stop'

Write-Host '== Checking for installed shells ==' -ForegroundColor Cyan

$candidates = [ordered]@{
    'PowerShell 7'   = 'C:\Program Files\PowerShell\7\pwsh.exe'
    'PowerShell 5.1' = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    'Command Prompt' = Join-Path $env:SystemRoot 'System32\cmd.exe'
    'Git Bash'       = 'C:\Program Files\Git\bin\bash.exe'
}

$found = 0
foreach ($name in $candidates.Keys) {
    $exe = $candidates[$name]
    if (Test-Path $exe) {
        Write-Host ("  [OK]   {0}: {1}" -f $name, $exe) -ForegroundColor Green
        $found++
    }
    else {
        Write-Host ("  [MISS] {0}: {1}" -f $name, $exe) -ForegroundColor Yellow
    }
}

if ($found -eq 0) {
    Write-Warning 'No shells detected. Install PowerShell and/or Git for Windows.'
}

Write-Host ''
Write-Host '== Registering the extension ==' -ForegroundColor Cyan

$params = @{}
if ($Publisher) {
    $params['Publisher'] = $Publisher
}

& (Join-Path $PSScriptRoot 'register.ps1') @params

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host ''
Write-Host 'Done.' -ForegroundColor Green
Write-Host '1. Start VS Code'
Write-Host '2. Ctrl+Shift+P -> Developer: Reload Window (if already open)'
Write-Host '3. Right-click a FOLDER in the Explorer (not a file)'
Write-Host '4. Look for: Open Shell Here: PowerShell / Git Bash / Command Prompt'
Write-Host '5. Or run from the Command Palette: "Open Shell Here:"'