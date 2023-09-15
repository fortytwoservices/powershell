# This script is used to import a base64 encoded PFX/PEM certificate as a certificate object to Azure Key Vault.
# vaultName: The name of the Azure Key Vault to import the certificate to.
# certificateData: The base64-encoded string of PFX/PEM certificate data.
# certificatePwd: The password of the PFX/PEM certificate.
# certificateName: The name of the certificate object to be created in Azure Key Vault.
param(
    [string] [Parameter(Mandatory=$true)] $vaultName,    
    [string] [Parameter(Mandatory=$true)] $certificateData,
    [string] [Parameter(Mandatory=$true)] $certificatePwd,
    [string] [Parameter(Mandatory=$true)] $certificateName
)

    $ErrorActionPreference = 'Stop'
    $DeploymentScriptOutputs = @{}

    $certificatePassword = ConvertTo-SecureString -String $certificatePwd -AsPlainText -Force
    Import-AzKeyVaultCertificate -VaultName $vaultName -Name $certificateName -CertificateString $certificateData -Password $certificatePassword
    
    $newCert = Get-AzKeyVaultCertificate -VaultName $vaultName -Name $certificateName
    $DeploymentScriptOutputs['certThumbprint'] = $newCert.Thumbprint
    $newCert | Out-String