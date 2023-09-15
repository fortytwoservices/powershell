param(
    [string] [Parameter(Mandatory=$true)] $vaultName,    
    [string] [Parameter(Mandatory=$true)] $certificateData,
    [string] [Parameter(Mandatory=$true)] $certificatePwd,
    [string] [Parameter(Mandatory=$false)] $certificateName = 'appgwcert'
)

    $ErrorActionPreference = 'Stop'
    $DeploymentScriptOutputs = @{}
    
    $certificatePassword = ConvertTo-SecureString -String $certificatePwd -AsPlainText -Force
    Import-AzKeyVaultCertificate -VaultName $vaultName -Name $certificateName -CertificateString $certificateData -Password $certificatePassword
    $newCert = Get-AzKeyVaultCertificate -VaultName $vaultName -Name $certificateName

    # Wait until upload to Key Vault is finished
    $tries = 0
    do {
    Write-Host 'Waiting for certificate import completion...'
    Start-Sleep -Seconds 10
    $operation = Get-AzKeyVaultCertificateOperation -VaultName $vaultName -Name $certificateName
    $tries++

    if ($operation.Status -eq 'failed')
    {
        throw 'Importing certificate $certificateName in vault $vaultName failed with error $($operation.ErrorMessage)'
    }

    if ($tries -gt 120)
    {
        throw 'Timed out waiting for import of certificate $certificateName in vault $vaultName'
    }
    } while ($operation.Status -ne 'completed')

    $DeploymentScriptOutputs['certThumbprint'] = $newCert.Thumbprint
    $newCert | Out-String