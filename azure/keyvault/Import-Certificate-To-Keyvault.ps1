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