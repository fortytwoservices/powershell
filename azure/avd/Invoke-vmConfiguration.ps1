# Script to configure the virtual machine with the desired settings

# run the script to install chocolatey (this is downloaded from chocolatey.org)
Write-Host -ForegroundColor DarkGreen "Executing the Chocolatey install.ps1 script"
try {
    & "$PSScriptRoot\Install-Chocolatey.ps1"
} catch {
    Write-Error "Error occurred while executing Install-Chocolatey.ps1: $_"
}

# run the script to initialize and format the data disk (this is downloaded from github)
Write-Host -ForegroundColor DarkGreen "Executing the Initialize-DataDisk.ps1 script"
try {
    & "$PSScriptRoot\Initialize-DataDisk.ps1"
} catch {
    Write-Error "Error occurred while executing Initialize-DataDisk.ps1: $_"
}
