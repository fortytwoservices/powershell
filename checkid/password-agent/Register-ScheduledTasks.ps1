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

.EXAMPLE
    PS C:\> .\Register-ScheduledTasks.ps1 -script c:\checkid\run.ps1 -gMSA account$ -runTask "Start agent" -taskStart "05:01" -preTask "Stop agent" -taskStop "05:00"
#>

param(
    # PowerShell 7+ executable, including full path
    [string] $pwsh = '"C:\Program Files\PowerShell\7\pwsh.exe"',
    # Script including full path
    [string] $script = 'C:\checkid\StartStop-CheckIDAgentListener.ps1',
    # Account name can be, and not limited to, group managed service account (if using a gMSA, including a trailing $)
    [string] $gMSA = 'checkidgMSA$',
    # Name of scheduled task that will run the password change agent. To avoid multiple instances the `$preTask will be run just before to stop the current task
    [string] $runTask = 'CheckID - start password change agent',
    # Time of day that `$runTask will start
    [String] $taskStart = "03:04",
    # Name of scheduled task that will stop the password change agent configured in `$runTask for a daily restart
    [string] $preTask = 'CheckID - stop agent for daily restart',
    # Time of day that `$preTask will start
    [string] $taskStop = "03:03",
    # Time (in seconds) that `$preTask waits before executing (Start-Sleep)
    [int] $waitBeforeStopInSeconds = 35,
    # Time (in seconds) that `$preTask will allow to pass, after trying to stop `$runTask, before throwing an error that `$runTask could not be stopped
    [int] $gracePeriodInSeconds = 15
)

#region RUN: At startup + daily at $taskStart

# Calculate working directory from `$script variable
$scriptName = $script.Split('\')[-1]
$workingDir = ($script -replace $scriptName, '').Trim('\')

$runAction = New-ScheduledTaskAction -Execute $pwsh -WorkingDirectory `"$workingDir`" -Argument "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$script`""

# OPTIONAL - PowerShell cmdlet New-ScheduledTaskTrigger helps to convert -At parameter value into [DateTime] object if it senses the input to be of type string
$taskStartDatetime = [datetime]::ParseExact($taskStart, "HH:mm", $null)

# Configure triggers for when to start `$runTask
$runTriggers = @(
    (New-ScheduledTaskTrigger -AtStartup),
    (New-ScheduledTaskTrigger -Daily -At $taskStartDateTime)
)
# Configure scheduled task settings which is applied when the task is running 
$runSettings = New-ScheduledTaskSettingsSet -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Seconds 0) -StartWhenAvailable
# Set property with value 3. Corresponds to 'Stop the existing instance'
$runSettings.CimInstanceProperties.Item('MultipleInstances').Value = 3 

# Provide identity in which context the scheduled task will run and set to run with highest (admin) RunLevel, if the identity holds such privileges
$principal = New-ScheduledTaskPrincipal -UserId $gMSA -LogonType Password -RunLevel Highest

# Look for an existing scheduled task with the name 
if (Get-ScheduledTaskInfo -TaskName $runTask -ErrorAction SilentlyContinue) { Unregister-ScheduledTask -TaskName $runTask -Confirm:$false -ErrorAction Stop }
# Register scheduled task
Register-ScheduledTask -TaskName $runTask -Action $runAction -Trigger $runTriggers -Settings $runSettings -Principal $principal -Description "Triggers $scriptName which runs continously. Script polls Fortytwo API for pending password reset requests from CheckID onboarding flow."
# Start scheduled task
Start-ScheduledTask -TaskName $runTask
#endregion

#region STOP: daily at $taskStop using -StopTask with -WaitToStopTaskInSeconds and -GraceSeconds
$preAction = New-ScheduledTaskAction -Execute $pwsh -WorkingDirectory `"$workingDir`" -Argument "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$script`" -StopTask -TaskName `"$runTask`" -WaitToStopTaskInSeconds $waitBeforeStopInSeconds -GraceSeconds $gracePeriodInSeconds"

# OPTIONAL - PowerShell cmdlet New-ScheduledTaskTrigger helps to convert -At parameter value into [DateTime] object if it senses the input to be of type string
$taskStopDatetime = [datetime]::ParseExact($taskStop, "HH:mm", $null)

$preTrigger = New-ScheduledTaskTrigger -Daily -At $taskStopDatetime
$preSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable

# Look for an existing scheduled task with the name 
if (Get-ScheduledTaskInfo -TaskName $preTask -ErrorAction SilentlyContinue) { Unregister-ScheduledTask -TaskName $preTask -Confirm:$false -ErrorAction Stop }
# Register scheduled task
Register-ScheduledTask -TaskName $preTask -Action $preAction -Trigger $preTrigger -Settings $preSettings -Principal $principal -Description "Stops $scriptName before daily restart."
#endregion