<#
.SYNOPSIS
    Script to be run one time to create a scheduled task with two triggers.

    Can be run the following ways:

        * as a standalone script with input parameters
        * as a standalone script where parameters are configured in the script
        * line by line execution within the script to have full control over each step

.NOTES
    By default the created scheduled task operates as follow:

        * STARTS script at system start up
        * STOPS script at 03:03:35 (03:03 + $waitBeforeStopInSeconds and then allows up to $gracePeriodInSeconds for the script to stop successfully)
        * STARTS script at 03:04:00

.EXAMPLE
    PS C:\> .\Register-ScheduledTasks.ps1
#>

param(
    [string] $pwsh = 'C:\Program Files\PowerShell\7\pwsh.exe',
    [string] $script = 'C:\checkid\StartStop-CheckIDAgentListener.ps1',
    [string] $gMSA = 'checkidgMSA',
    [string] $runTask = 'CheckID - start password change agent',
    [string] $preTask = 'CheckID - stop agent for daily restart',
    [String] $taskStart = "03:04",
    [string] $taskStop = "03:03",
    [int] $waitBeforeStopInSeconds = 35,
    [int] $gracePeriodInSeconds = 15
)

# RUN: At startup + daily at $taskStart
$runAction = New-ScheduledTaskAction -Execute $pwsh -Argument "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$script`""
# OPTIONAL - PowerShell cmdlet New-ScheduledTaskTrigger helps to convert -At parameter value into [DateTime] object if it senses the input to be of type string
$taskStartDatetime = [datetime]::ParseExact($taskStart, "HH:mm", $null)
$runTriggers = @(
    (New-ScheduledTaskTrigger -AtStartup),
    (New-ScheduledTaskTrigger -Daily -At $taskStartDateTime)
)
$runSettings = New-ScheduledTaskSettingsSet -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Seconds 0) -StartWhenAvailable $runSettings.CimInstanceProperties.Item('MultipleInstances').Value = 3   # 3 corresponds to 'Stop the existing instance'
    
$principal = New-ScheduledTaskPrincipal -UserId $gMSA -LogonType Password -RunLevel Highest
    
if (Get-ScheduledTaskInfo -TaskName $runTask -ErrorAction SilentlyContinue) { Unregister-ScheduledTask -TaskName $runTask -Confirm:$false -ErrorAction Stop }
Register-ScheduledTask -TaskName $runTask -Action $runAction -Trigger $runTriggers -Settings $runSettings -Principal $principal -Description "Triggers $($script.Split('\')[-1]) which runs continously. Script polls Fortytwo API for pending password reset requests from CheckID onboarding flow."
Start-ScheduledTask -TaskName $runTask
    
# STOP: daily at $taskStop using -StopTask with -WaitToStopTaskInSeconds and -GraceSeconds
$preAction = New-ScheduledTaskAction -Execute $pwsh -Argument "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$script`" -StopTask -TaskName `"$runTask`" -WaitToStopTaskInSeconds $waitBeforeStopInSeconds -GraceSeconds $gracePeriodInSeconds"
# OPTIONAL - PowerShell cmdlet New-ScheduledTaskTrigger helps to convert -At parameter value into [DateTime] object if it senses the input to be of type string
$taskStopDatetime = [datetime]::ParseExact($taskStop, "HH:mm", $null)
$preTrigger = New-ScheduledTaskTrigger -Daily -At $taskStopDatetime
$preSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable
if (Get-ScheduledTaskInfo -TaskName $preTask -ErrorAction SilentlyContinue) { Unregister-ScheduledTask -TaskName $preTask -Confirm:$false -ErrorAction Stop }
Register-ScheduledTask -TaskName $preTask -Action $preAction -Trigger $preTrigger -Settings $preSettings -Principal $principal -Description "Stops $($script.Split('\')[-1]) before daily restart."