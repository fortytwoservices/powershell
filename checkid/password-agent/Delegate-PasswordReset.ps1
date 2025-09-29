<#
.SYNOPSIS
    Script that delegates Active Directory Reset Password permission (for user class objects) to a specified organization unit for the provided account.
    Script can be run with -WhatIf and -Confirm flags, either / or and both at the same time.
    
    Requires both $DistinguishedName and -AccountSam parameters as well as valid values for both (will throw error if one of the other is not found).

.PARAMETER AccountSam
    Account name (sAMAccount) of the account to be delegated Reset Password rights

.PARAMETER DistinguishedName
    Organizational unit (provided on distinguished name format) where Reset Password permission will be applied

.EXAMPLE
    PS C:\> .\Add-ResetPasswordDelegation -DistinguishedName "OU=users,OU=organization,DC=fabrikam,DC=com" -AccountSam checkidgMSA$ -Confirm

    Add permission (with -Confirm). Will report if the permission is already in place, even with -Confirm present.

.EXAMPLE
    PS C:\> .\Add-ResetPasswordDelegation -DistinguishedName "OU=users,OU=organization,DC=fabrikam,DC=com" -AccountSam checkidgMSA$ -WhatIf

    Add permission (with -WhatIf). Will report if the permission is already in place, even with -WhatIf present.

.EXAMPLE
    PS C:\> .\Remove-ResetPasswordDelegation -DistinguishedName "OU=users,OU=organization,DC=fabrikam,DC=com" -AccountSam checkidgMSA$ -Confirm

    Remove permission

.EXAMPLE
    PS C:\> $restore = "C:\Users\xxx\AppData\Local\Temp\ACL-Backup_OU_DC_20250915-220453.sddl"
    PS C:\> .\Restore-AdObjectAcl -DistinguishedName "OU=users,OU=organization,DC=fabrikam,DC=com" -Path $restore -Confirm

    Restore organizational unit access control list using a specified backup file

.NOTES
    To confirm successful script execution it can be comforting to run a "before" and "after" check, independent of the script.
    Use 'dsacls' to look through the access control entries on any OU. This tool will return the account name and permission it is provided.
    ('dsacls' is an Active Directory tool included on domain controllers. Other server types may need to have this installed separately)

    (Optional) PRE-CHECK:

    PS C:\> $AccountSam = "checkid" # will match either the account is called 'checkid' or 'checkidgMSA$' because of the Select-String -SimpleMatch
    PS C:\> dsacls "OU=users,OU=organization,DC=fabrikam,DC=com" | Select-String -SimpleMatch checkidgMSA$

    (*EMPTY* <- see POST-CHECK for how it would display if an existing entry is found)

    PS C:\> .\Delegate-PasswordReset.ps1 -AccountSam "checkidgMSA$" -DistinguishedName "OU=users,OU=organization,DC=fabrikam,DC=com" -Confirm

    ACL-backup path: C:\Users\XXX\AppData\Local\Temp\ACL-Backup_OU_users_OU_organization_DC_fabrikam_DC_com_20250917-125029.sddl

    Confirm
    Are you sure you want to perform this action?
    Performing the operation "Add 'Reset Password' (ExtendedRight) for FABRIKAM\checkidgMSA$, inheritance=user" on target "OU=users,OU=organization,DC=fabrikam,DC=com".
    [Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "Y"):
    
    If the scripted delegation goes well proceed to the next step. Run the script again with with parameters:

    PS C:\> .\Delegate-PasswordReset.ps1 -AccountSam "checkidgMSA$" -DistinguishedName "OU=users,OU=organization,DC=fabrikam,DC=com" -WhatIf

    ACL-backup path: C:\Users\XXX\AppData\Local\Temp\ACL-Backup_OU_users_OU_organization_DC_farbikam_DC_com_20250917-125044.sddl
    ACE already exists for FABRIKAM\checkidgMSA$ on OU=users,OU=organization,DC=fabrikam,DC=com (Reset Password → user). No change.

    (Optional) POST-CHECK:

    PS C:\> dsacls "OU=users,OU=organization,DC=fabrikam,DC=com" | Select-String -SimpleMatch $AccountSam

    Allow FABRIKAM\checkidgMSA$        Reset Password
#>

#requires -Modules ActiveDirectory
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    # Account name, including '$' when it's a group managed service account
    [Parameter(Mandatory = $true)]
    [string]$AccountSam,

    # Specify distinguished name for where to apply delegation
    [Parameter(Mandatory = $true)]
    [string]$DistinguishedName
)

# Connect to specified organizational unit in Active Directory
function Get-DirectoryEntry {
    param([Parameter(Mandatory)][string]$DistinguishedName)
    return New-Object System.DirectoryServices.DirectoryEntry("LDAP://$DistinguishedName")
}

# Resolve the GUID for the Active Directory 'Extended-Rights (Reset Password) permission
function Get-ResetPasswordGuid {
    $rootDse = Get-ADRootDSE
    $configNC = $rootDse.ConfigurationNamingContext
    $obj = Get-ADObject -SearchBase ("CN=Extended-Rights," + $configNC) -LDAPFilter "(displayName=Reset Password)" -Properties rightsGuid
    if (-not $obj) { throw "Could not finde 'Reset Password' in Extended-Rights." }
    return [Guid]$obj.rightsGuid
}

# Resolve the GUID for the 'user class' in Active Directory
function Get-UserClassGuid {
    $schemaNC = (Get-ADRootDSE).SchemaNamingContext
    $obj = Get-ADObject -SearchBase $schemaNC -LDAPFilter "(lDAPDisplayName=user)" -Properties schemaIDGUID
    return [Guid]$obj.schemaIDGUID
}

# Get the security identifier (sid) for the provided account name 
function Get-AccountSid {
    param([Parameter(Mandatory)][string]$SamAccount)
    return ([System.Security.Principal.NTAccount]$SamAccount).Translate([System.Security.Principal.SecurityIdentifier])
}

# Backup access control entries for the provided organizational unit
function Backup-AdObjectAcl {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string]$DistinguishedName,
        [Parameter(Mandatory)][string]$Path
    )
    if ($PSCmdlet.ShouldProcess($DistinguishedName, "Backup ACL to $Path")) {
        $entry = Get-DirectoryEntry -DistinguishedName $DistinguishedName
        $sd = $entry.ObjectSecurity
        $sddl = $sd.GetSecurityDescriptorSddlForm('All')
        $sddl | Out-File -LiteralPath $Path -Encoding ASCII -Force
        Write-Verbose "ACL backup saved at $Path"
    }
}

# Restore access control entries for the provided organizational unit
function Restore-AdObjectAcl {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][string]$DistinguishedName,
        [Parameter(Mandatory)][string]$Path
    )
    $sddl = Get-Content -LiteralPath $Path -Raw
    if (-not $sddl) { throw "Kunne ikke lese SDDL fra $Path" }
    if ($PSCmdlet.ShouldProcess($DistinguishedName, "Restore ACL fra $Path")) {
        $entry = Get-DirectoryEntry -DistinguishedName $DistinguishedName
        $sd = $entry.ObjectSecurity
        $sd.SetSecurityDescriptorSddlForm($sddl, 'All')
        $entry.ObjectSecurity = $sd
        $entry.CommitChanges()
        Write-Host "ACL restaurert fra $Path"
    }
}

# Check if an access control entry belonging to the account name already exists with AD permission 'ExtendedRight'
function Test-HasAce {
    param(
        [System.DirectoryServices.ActiveDirectorySecurity]$SecurityDescriptor,
        [System.Security.Principal.SecurityIdentifier]$Sid,
        [Guid]$ObjectTypeGuid,
        [Guid]$InheritedObjectTypeGuid
    )
    $found = $false
    foreach ($rule in $SecurityDescriptor.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])) {
        if ($rule.IdentityReference -ne $Sid) { continue }
        if ($rule.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) {
            if ($rule.AccessControlType -eq 'Allow' -and
                $rule.ObjectType -eq $ObjectTypeGuid -and
                $rule.InheritanceType -eq [System.DirectoryServices.ActiveDirectorySecurityInheritance]::Descendents -and
                $rule.InheritedObjectType -eq $InheritedObjectTypeGuid) {
                $found = $true; break
            }
        }
    }
    return $found
}

# Add access control entry for account name in organizational unit with permission 'Extended-Rights'
function Add-ResetPasswordDelegation {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)][string]$DistinguishedName,
        [Parameter(Mandatory)][string]$AccountSam
    )
    $dom = Get-ADDomain
    $acct = if ($AccountSam -match '\\') { $AccountSam } else { "$($dom.NetBIOSName)\$AccountSam" }
    # Get-AccountSid fails to look up group managed service accounts unless a trailing '$' is included
    $sid = Get-AccountSid -SamAccount $acct
    $resetPwdGuid = Get-ResetPasswordGuid
    $userClassGuid = Get-UserClassGuid

    $entry = Get-DirectoryEntry -DistinguishedName $DistinguishedName
    $sd = $entry.ObjectSecurity

    # Build the rule (ExtendedRight: Reset Password, inherit on user class)
    $rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule `
    ($sid,
        [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight,
        [System.Security.AccessControl.AccessControlType]::Allow,
        $resetPwdGuid,
        [System.DirectoryServices.ActiveDirectorySecurityInheritance]::Descendents,
        $userClassGuid)

    if (Test-HasAce -SecurityDescriptor $sd -Sid $sid -ObjectTypeGuid $resetPwdGuid -InheritedObjectTypeGuid $userClassGuid) {
        Write-Host "ACE already exists for $acct on $DistinguishedName (Reset Password → user). No change."
        return
    }

    if ($PSCmdlet.ShouldProcess("$DistinguishedName", "Add 'Reset Password' (ExtendedRight) for $acct, inheritance=user")) {
        $sd.AddAccessRule($rule) | Out-Null
        $entry.ObjectSecurity = $sd
        $entry.CommitChanges()
        Write-Host "Added 'Reset Password' for $acct on $DistinguishedName (inherit: user)."
    }
}

# Remove access control entry for account name in organizational unit
function Remove-ResetPasswordDelegation {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][string]$DistinguishedName,
        [Parameter(Mandatory)][string]$AccountSam
    )
    $dom = Get-ADDomain
    $acct = if ($AccountSam -match '\\') { $AccountSam } else { "$($dom.NetBIOSName)\$AccountSam" }
    $sid = Get-AccountSid -SamAccount $acct
    $resetPwdGuid = Get-ResetPasswordGuid
    $userClassGuid = Get-UserClassGuid

    $entry = Get-DirectoryEntry -DistinguishedName $DistinguishedName
    $sd = $entry.ObjectSecurity

    $rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule `
    ($sid,
        [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight,
        [System.Security.AccessControl.AccessControlType]::Allow,
        $resetPwdGuid,
        [System.DirectoryServices.ActiveDirectorySecurityInheritance]::Descendents,
        $userClassGuid)

    if ($PSCmdlet.ShouldProcess("$DistinguishedName", "Remove 'Reset Password' ACE for $acct (inheritance=user)")) {
        $removed = $sd.RemoveAccessRule($rule)
        if ($removed) {
            $entry.ObjectSecurity = $sd
            $entry.CommitChanges()
            Write-Host "Removed 'Reset Password' ACE for $acct on $DistinguishedName."
        }
        else {
            Write-Host "Could not find a matching ACE to remove (could be normalized). Consider full SDDL-restore."
        }
    }
}

# ---------- RUN ----------

$domain = Get-ADDomain
if (-not $DistinguishedName) { $DistinguishedName = $domain.DistinguishedName }

# SDDL-backup before change
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $env:TEMP ("ACL-Backup_{0}_{1}.sddl" -f ($DistinguishedName -replace '[\\/:*?"<>|=,]', '_'), $ts)

Backup-AdObjectAcl -DistinguishedName $DistinguishedName -Path $backup -WhatIf:$false
Write-Host "ACL-backup path: $backup"

# Add delegation (supports -WhatIf / -Confirm)
Add-ResetPasswordDelegation @PSBoundParameters