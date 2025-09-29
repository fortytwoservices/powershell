<#
.SYNOPSIS
    Helper script to test encryption settings for a group managed service account (gMSA) against one or more domain controllers

.PARAMETER gMSAName
    Name of gMSA to test encryption settings

.PARAMETER TargetComputers
    Name of domain controller(s) to test encryption settings

.PARAMETER (OPTIONAL) DomainDN
    Domain name in disinguished name format

.EXAMPLE
    PS \> .\Test-gMSAencryptionSettings.ps1 -gMSAName checkidgMSA

.EXAMPLE
    PS \> .\Test-gMSAencryptionSettings.ps1 -gMSAName checkidgMSA -TargetComputers FABRIKAM-DC01

.NOTES
    Limited error handling. If the $gMSAName does not exist Get-ADObject cmdlet throws: "Directory object not found."
#>

param (
    [Parameter(Mandatory=$false)]
    [string] $gMSAName = "checkidgMSA",

    [Parameter(Mandatory=$false)]
    [string[]] $TargetComputers, #= @("DOMAINCONTROLLER01", "DOMAINCONTROLLER02"),
    
    [Parameter(Mandatory=$false)]
    [string] $DomainDN = "DC=$($env:USERDNSDOMAIN.Split('.')[0]),DC=$($env:USERDNSDOMAIN.Split('.')[1])"
)

# Fetch account msDS-SupportedEncryptionTypes value, calculate configured encryption, return value and types
function Get-EncryptionTypes {
    param([string]$ObjectName)

    $encValue = (Get-ADObject -Identity $ObjectName -Properties msDS-SupportedEncryptionTypes).'msDS-SupportedEncryptionTypes'
    if (-not $encValue) { $encValue = 0 }

    $types = @{
        1 = 'DES-CBC-CRC'
        2 = 'DES-CBC-MD5'
        4 = 'RC4-HMAC'
        8 = 'AES128'
        16 = 'AES256'
        32 = 'Future'
    }

    $decoded = $types.Keys | Where-Object { $encValue -band $_ } | ForEach-Object { $types[$_] }

    return @{
        Raw = $encValue
        Decoded = $decoded -join ', '
    }
}

# Strip trailing '$' as this is NOT part of the gMSA distinguished name (nor any DN)
$gMSAName = $gMSAName -notmatch "\$" ? $gMSAName : $gMSAName.TrimEnd("$")

Write-Host "`n🔍 Checking gMSA '$gMSAName' encryption settings..." -ForegroundColor Cyan
$gmsaEnc = Get-EncryptionTypes -ObjectName "CN=$gMSAName,CN=Managed Service Accounts,$DomainDN"
Write-Host "gMSA encryption: $($gmsaEnc.Raw) ($($gmsaEnc.Decoded))`n"

foreach ($comp in $TargetComputers) {
    Write-Host "🔸 Checking '$comp'..." -ForegroundColor Yellow
    try {
        $compEnc = Get-EncryptionTypes -ObjectName "CN=$comp,OU=Domain Controllers,$DomainDN"

        Write-Host "    Computer encryption: $($compEnc.Raw) ($($compEnc.Decoded))"

        if ($compEnc.Raw -ne $gmsaEnc.Raw) {
            Write-Host "    ⚠️  Mismatch detected! Consider aligning these values." -ForegroundColor Red
        } else {
            Write-Host "    ✅ Compatible" -ForegroundColor Green
        }
    } catch {
        Write-Host "    ❌ Could not retrieve info for $comp. $_" -ForegroundColor Red
    }

    Write-Host ""
}