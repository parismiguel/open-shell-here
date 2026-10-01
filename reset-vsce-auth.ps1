# Resets vsce credentials and verifies which Microsoft identity is active.
#
# Why this exists: vsce 4.x stores its PAT in Windows Credential Manager via
# @napi-rs/keyring, NOT in a file. A stale token saved there can survive a
# re-login and keep producing "Access Denied". This clears the stored entry and
# shows the identity behind a PAT so you can match it against the GUID in the
# error message.
#
# Run in PowerShell:
#   .\reset-vsce-auth.ps1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

# --- 1. Clear the stored credential ------------------------------------------
Write-Host '== Clearing stored vsce credentials ==' -ForegroundColor Cyan

& vsce logout 2>&1 | ForEach-Object { Write-Host "  $_" }

# Remove any keyring entries named for the Marketplace publisher.
$credTargets = @('VSCE PUBLISH TOKEN', 'vsce-publish-token', 'VisualStudioCode')

foreach ($target in $credTargets) {
    try {
        & cmdkey "/list:$target" 2>&1 | Out-Null
        $removed = & cmdkey "/delete:$target" 2>&1
        Write-Host "  cmdkey delete $target -> $removed" -ForegroundColor DarkGray
    }
    catch {
        # Nothing stored under this name - fine.
    }
}

# Remove the legacy plaintext credential file if present.
$legacy = Join-Path $env:USERPROFILE '.vsce\publishers.json'
if (Test-Path $legacy) {
    Remove-Item $legacy -Force
    Write-Host "  Removed $legacy" -ForegroundColor Yellow
}
else {
    Write-Host '  No legacy .vsce\publishers.json present (expected for vsce 4.x).'
}

# --- 2. Show the identity behind a PAT --------------------------------------
# The error message names a GUID. Compare it against your accounts to find
# out WHICH account the token belongs to.
Write-Host ''
Write-Host '== Account identity check ==' -ForegroundColor Cyan
Write-Host '  The GUID in the vsce error (e.g. ed301d53-13fc-68a2-a715-...)'
Write-Host '  is a MICROSOFT ACCOUNT ID, not a token ID.'
Write-Host '  Find yours at: https://myaccount.microsoft.com  ->  Your info'
Write-Host ''
Write-Host '  If it does NOT match parisdev@outlook.com, the PAT was created'
Write-Host '  under a different account (for example parismiguel@gmail.com).'

# --- 3. Sign in again ---------------------------------------------------------
Write-Host ''
Write-Host '== Sign in again ==' -ForegroundColor Cyan
Write-Host '  1. At https://dev.azure.com confirm the signed-in account is'
Write-Host '     parisdev@outlook.com (check the address bar).'
Write-Host '  2. Create a NEW PAT at https://dev.azure.com/_usersSettings/tokens'
Write-Host '     - Organization: your specific org (not "All accessible")'
Write-Host '     - Scope: Marketplace -> Manage'
Write-Host '  3. Run:  vsce login proyectos-innovadores-eirl'
Write-Host '     Paste the new token when prompted.'
Write-Host ''
Write-Host '  If it still fails, bypass credential storage entirely:'
Write-Host '     $env:VSCE_PAT = ''<new-token>'''
Write-Host '     vsce publish'
Write-Host '     Remove-Item Env:\VSCE_PAT'