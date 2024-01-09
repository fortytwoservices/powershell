$contentAdmin = @'
Start-Transcript -Path "C:\ProgramData\CustomScripts\appUpdateLogAdmin.txt"# Logging

winget upgrade --accept-package-agreements --accept-source-agreements --silent --force --all

Stop-Transcript
'@

$contentUser = @'
Start-Transcript -Path "C:\ProgramData\CustomScripts\appUpdateLogUser.txt"# Logging

winget upgrade --accept-package-agreements --accept-source-agreements --silent --force --all

Stop-Transcript
'@

$contentSystem = @'
Start-Transcript -Path "C:\ProgramData\CustomScripts\appUpdateLogSystem.txt"# Logging

$winget_path = "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
Set-Location $winget_path

.\winget upgrade --accept-package-agreements --accept-source-agreements --silent --force --all

Stop-Transcript
'@
 
# create custom folder and write PS script
$path = $(Join-Path $env:ProgramData CustomScripts)
if (!(Test-Path $path)) {
    New-Item -Path $path -ItemType Directory -Force -Confirm:$false
}
Out-File -FilePath $(Join-Path $env:ProgramData CustomScripts\WingetUppgradeAppsAdmin.ps1) -Encoding unicode -Force -InputObject $contentAdmin -Confirm:$false
Out-File -FilePath $(Join-Path $env:ProgramData CustomScripts\WingetUppgradeAppsUser.ps1) -Encoding unicode -Force -InputObject $contentUser -Confirm:$false
Out-File -FilePath $(Join-Path $env:ProgramData CustomScripts\WingetUppgradeAppsSystem.ps1) -Encoding unicode -Force -InputObject $contentSystem -Confirm:$false
 
# register script as scheduled task

$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -DontStopOnIdleEnd
$ActionAdmin = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ex bypass -WindowStyle Hidden -file `"C:\ProgramData\CustomScripts\WingetUppgradeAppsAdmin.ps1`""
$ActionUser = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ex bypass -WindowStyle Hidden -file `"C:\ProgramData\CustomScripts\WingetUppgradeAppsUser.ps1`""
$ActionSystem = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ex bypass -file `"C:\ProgramData\CustomScripts\WingetUppgradeAppsSystem.ps1`""

$adminTime = @(New-ScheduledTaskTrigger -Daily -At 2:15pm)
$adminPrincipal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest
Register-ScheduledTask -TaskName "UpgradeAppsAsAdmin" -Trigger $adminTime -Principal $adminPrincipal -Action $ActionAdmin -Force -Settings $Settings
$userTime = @(New-ScheduledTaskTrigger -Daily -At 2:30pm)
$userPrincipal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest
Register-ScheduledTask -TaskName "UpgradeAppsAsUser" -Trigger $userTime -Principal $userPrincipal -Action $ActionUser -Force -Settings $Settings
$systemTime = @(New-ScheduledTaskTrigger -Daily -At 2:45pm)
$systemUser = "SYSTEM"
Register-ScheduledTask -TaskName "UpgradeAppsAsSystem" -Trigger $systemTime -User $systemUser -Action $ActionSystem -Force -Settings $Settings