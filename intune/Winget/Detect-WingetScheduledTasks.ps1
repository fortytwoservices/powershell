# Detect if files exist
$WingetUppgradeAppsAdmin = "C:\ProgramData\CustomScripts\WingetUppgradeAppsAdmin.ps1"
$WingetUppgradeAppsUser = "C:\ProgramData\CustomScripts\WingetUppgradeAppsUser.ps1"
$WingetUppgradeAppsSystem = "C:\ProgramData\CustomScripts\WingetUppgradeAppsSystem.ps1"

if ((Test-Path $WingetUppgradeAppsAdmin) -and (Test-Path $WingetUppgradeAppsUser) -and (Test-Path $WingetUppgradeAppsSystem)) { 
    Write-host "Found Winget Scheduled Tasks" 
}
else {
    Write-host "Winget Scheduled Tasks not found" 
    exit 1
}