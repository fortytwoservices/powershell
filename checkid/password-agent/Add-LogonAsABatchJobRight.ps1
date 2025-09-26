<#
.SYNOPSIS
    Script provides local security policy user right "Log on as a batch job" to an account.
    Right "Log on as a batch job" must be held for an account to run a non-interactive scheduled task

.PARAMETER AccountSam
    Account name (sAMAccount or FQDN) to be added to list to be allowed to "Log on as a batch job"

.PARAMETER DistinguishedName
    Organizational unit (provided on distinguished name format) where Reset Password permission will be applied

.EXAMPLE
    PS C:\> .\Add-LogonAsABatchJobRight -AccountSam checkidgMSA$

.EXAMPLE
    PS C:\> .\Add-LogonAsABatchJobRight -AccountSam checkidgMSA$ -Remove
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)]
    [string]$AccountSam,     # e.g. 'FABRIKAM\checkidgMSA$' or 'MACHINE\svc'
    [switch]$Remove
)

# Resolve and return the SID for the account
function Get-SidString {
    param([Parameter(Mandatory)][string]$Sam)
    try {
        return ([System.Security.Principal.NTAccount]$Sam).Translate([System.Security.Principal.SecurityIdentifier]).Value
    }
    catch {
        throw "No account found: $Sam"
    }
}

# Export current local security policy to read current state and update User Rights Assignment for "Log on as a batch job"
function Export-UserRights {
    param([Parameter(Mandatory)][string]$Path)
    secedit /export /cfg "$Path" | Out-Null
    if (-not (Test-Path -LiteralPath $Path)) { throw "Could not export security policy to $Path" }
}

# Resolve SIDs of all SeBatchLogonRight from exported security policy .inf (e.g. SeBatchLogonRight = *S-1-5-32-544,*S-1-5-32-551)
function Get-SeBatchLogonRightSids {
    param([Parameter(Mandatory)][string]$CfgPath)
    $lines = Get-Content -LiteralPath $CfgPath
    # Find section [Privilege Rights]
    $start = ($lines | Select-String -SimpleMatch '[Privilege Rights]').LineNumber
    if (-not $start) { return @() } # no section => no explicit line
    $section = $lines[($start)..($lines.Length - 1)] | Where-Object { $_ -notmatch '^\s*\[' -or $_ -match '^\s*\[Privilege Rights\]\s*$' }
    $line = $section | Where-Object { $_ -match '^\s*SeBatchLogonRight\s*=' } | Select-Object -First 1
    if (-not $line) { return @() }
    $value = ($line -split '=', 2)[1].Trim()
    if (-not $value) { return @() }
    # Format of INF is "*SID,*SID2,..."
    $parts = $value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    # Trim leading '*' for every entry
    return $parts | ForEach-Object { $_.TrimStart('*') }
}

# Create new security policy .inf with updated SeBatchLogonRight (SIDs to be included in a string[] list)
function New-InfForBatchRight {
    param(
        [Parameter(Mandatory)][string[]]$SidList
    )
    # 1) Prefix SIDs with '*' and join with ,
    $joined = (($SidList | ForEach-Object { '*{0}' -f $_ }) -join ',')

    # 2) Normalise – remove unintended spaces
    $joined = ($joined -replace '\s*,\s*', ',')

    # 3) Protect against CR/LF (result must be on a single line)
    $joined = $joined -replace '[\r\n]+', ''

    # 4) Validate
    if ($joined -notmatch '^\*S-1-5-' ) { throw "SID-list has incorrect format: '$joined'" }
    if ($SidList.Count -gt 1 -and $joined -notmatch ',') { throw "Missing comma-separation in SID-list: '$joined'" }

    # 5) Preview log
    Write-Host "INF-line preview:" -ForegroundColor Cyan
    Write-Host ("SeBatchLogonRight = {0}" -f $joined) -ForegroundColor Yellow

    # 6) Return the INF content
    @(
        '[Unicode]'
        'Unicode=yes'
        '[Version]'
        'signature="$CHICAGO$"'
        'Revision=1'
        '[Privilege Rights]'
        ('SeBatchLogonRight = ' + $joined)
    ) -join [Environment]::NewLine
}

# --- 1) Look up SID and export current policy ---
$sid = Get-SidString -Sam $AccountSam
$tmpExport = Join-Path $env:TEMP "secpol_export_$(Get-Date -Format yyyyMMdd_HHmmss).inf"
Export-UserRights -Path $tmpExport

# --- 2) Read "before-state" ---
$beforeSids = @(Get-SeBatchLogonRightSids -CfgPath $tmpExport)  # always string[]
# --- Create a hashset and fill it with the returned SIDs ---
$beforeSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$beforeSids)

# --- 3) Calculate "after-state" in memory ---
$afterSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$beforeSids)

# Remove SID from existing list of User Rights Assignment if run with -Remove parameter
if ($Remove) {
    [void]$afterSet.Remove($sid)
}
else {
    [void]$afterSet.Add($sid)
}

# --- 4) Diff (added/removed) ---
# Convert HashSet -> string[]
$afterSids = New-Object string[] ($afterSet.Count)
$afterSet.CopyTo($afterSids, 0)

$added = $afterSids  | Where-Object { $_ -and ($beforeSet.Contains($_) -eq $false) }
$removed = $beforeSids | Where-Object { $_ -and ($afterSet.Contains($_) -eq $false) }

Write-Host "`n=== SeBatchLogonRight diff for $AccountSam ==="
if ($added) { Write-Host "  + Added:"; $added   | ForEach-Object { Write-Host "    + $_" } }
if ($removed) { Write-Host "  - Removed:"  ; $removed | ForEach-Object { Write-Host "    - $_" } }
if (-not $added -and -not $removed) { Write-Host "  (No change necessary)" }

# --- 5) Build INF for desired after-state ---
$afterSidsSorted = $afterSids | Sort-Object
Write-Host "`nAfterSidsSorted: $afterSidsSorted"
$infContent = New-InfForBatchRight -SidList $afterSidsSorted
$tmpApply = Join-Path $env:TEMP "secpol_apply_$(Get-Date -Format yyyyMMdd_HHmmss).inf"
$infContent | Set-Content -LiteralPath $tmpApply -Encoding ASCII

# --- 6) Execute change (works with -WhatIf/-Confirm) ---
if ($PSCmdlet.ShouldProcess("Local security policy", ("{0} '{1}' in SeBatchLogonRight" -f ($Remove ? 'Remove' : 'Add'), $AccountSam))) {
    secedit /configure /db "$env:TEMP\secedit.sdb" /cfg "$tmpApply" /areas USER_RIGHTS | Out-Null
    Write-Host "`nUpdated SeBatchLogonRight. (Source: $tmpApply)"
    # Use gpupdate if change isn't effective immediately:
    # gpupdate /target:computer /force | Out-Null
}

# --- 7) Show "after" if the script ran without -WhatIf ---
if (-not $WhatIfPreference) {
    $verifyExport = Join-Path $env:TEMP "secpol_verify_$(Get-Date -Format yyyyMMdd_HHmmss).inf"
    Export-UserRights -Path $verifyExport
    $now = @(Get-SeBatchLogonRightSids -CfgPath $verifyExport)
    Write-Host "`nCurrent SeBatchLogonRight SIDs:"
    if ($now) { $now | ForEach-Object { Write-Host "  * $_" } } else { Write-Host "  (none)" }
}