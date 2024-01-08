$content = @'
Start-Transcript -Path "C:\ProgramData\CustomScripts\AppUpdateLog.txt"# Logging

winget source remove msstore
winget source reset --force 
winget upgrade --accept-package-agreements --accept-source-agreements --silent --all

Stop-Transcript
'@

 
# create custom folder and write PS script
$path = $(Join-Path $env:ProgramData CustomScripts)
if (!(Test-Path $path)) {
    New-Item -Path $path -ItemType Directory -Force -Confirm:$false
}
Out-File -FilePath $(Join-Path $env:ProgramData CustomScripts\WingetUppgradeApps.ps1) -Encoding unicode -Force -InputObject $content -Confirm:$false
 
# register script as scheduled task
$Time = @(New-ScheduledTaskTrigger -Daily -At 11am; New-ScheduledTaskTrigger -AtLogOn)
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -DontStopOnIdleEnd
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ex bypass -WindowStyle Hidden -file `"C:\ProgramData\CustomScripts\WingetUppgradeApps.ps1`""

$adminPrincipal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest
Register-ScheduledTask -TaskName "UpgradeAppsAsAdmin" -Trigger $Time -Principal $adminPrincipal -Action $Action -Force -Settings $Settings
$userPrincipal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest
Register-ScheduledTask -TaskName "UpgradeAppsAsUser" -Trigger $Time -Principal $userPrincipal -Action $Action -Force -Settings $Settings
$systemUser = "SYSTEM"
Register-ScheduledTask -TaskName "UpgradeAppsAsSystem" -Trigger $Time -User $systemUser -Action $Action -Force -Settings $Settings

Start-ScheduledTask -TaskName "UpgradeAppsAsAdmin"
Start-ScheduledTask -TaskName "UpgradeAppsAsUser"
Start-ScheduledTask -TaskName "UpgradeAppsAsSystem"