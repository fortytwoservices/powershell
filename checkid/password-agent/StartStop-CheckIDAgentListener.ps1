<#
.SYNOPSIS
    Script to be run as scheduled task by a group managed service account or service account that holds Reset Password Active Directory permissions.

.DESCRIPTION
    The script supports switch parameter -StopTask to which parameters WaitToStopTaskInSeconds and GraceSeconds also can configured.

    Normal script execution, without any parameters, will load required modules, connect the agent to the Fortytwo API and start the listener.

    REQUIREMENT!
    The PowerShell modules must reside in the same folder, or folder name / path must be updated in the script.
    The script required the following parameters *in the script* to be replaced with values from your environment:

        * THUMBPRINT
        * CLIENTID
        * TENANTID

.PARAMETER TaskName
    Optional - Defaults to 'CheckID-adagent for password change'

.PARAMETER StopTask
    Optional - Used for scheduled stopping of the agent listener.

.PARAMETER WaitToStopTaskInSeconds
    Optional - Used with parameter switch StopTask. Sets the delay from which the task is started until it's executed (Start-Sleep -Seconds)

.PARAMETER GraceSeconds
    Optional - Used with parameter switch StopTask. Defines a maximum period for the scheduled task to enter 'Stopped' state before throwing an error.

.EXAMPLE
    PS C:\> .\StartStop-CheckIDAgentListener.ps1
    
.EXAMPLE
    PS C:\> .\StartStop-CheckIDAgentListener.ps1 -TaskName "CheckID password agent"

.EXAMPLE
    PS C:\> .\StartStop-CheckIDAgentListener.ps1 -StopTask -WaitToStopTaskInSeconds 25 -GraceSeconds 25
#>

param(
    [Parameter(Mandatory = $false)]
    [switch] $StopTask,
    
    # Name of the scheduled task (Active Directory agent that polls Fortytwo API for incoming password change requests)
    [Parameter(Mandatory = $false)]
    [string] $TaskName = 'CheckID-adagent for password change',
    
    # Delay to wait before executing the stop scheduled task command
    [Parameter(Mandatory = $false)]
    [int] $WaitToStopTaskInSeconds = 35,
    [Parameter(Mandatory = $false)]
    # How long to wait for the scheduled task to be stopped gracefully
    [int] $GraceSeconds = 15
)

#region Start scheduled task
if (-not $StopTask) {

    Install-Module Fortytwo.CheckID.PasswordAgent -Confirm:$false -Force -Verbose -Scope CurrentUser
    Import-Module Fortytwo.CheckID.PasswordAgent -Force
    Import-Module EntraIDAccessToken -Force

    Add-EntraIDClientCertificateAccessTokenProfile `
        -Resource "2808f963-7bba-4e66-9eee-82d0b178f408" `
        -Thumbprint "THUMBPRINT" `
        -ClientId "CLIENTID" `
        -TenantId "TENANTID"
        
    Connect-CheckIDPasswordAgent `
        -AgentID "AGENTID" `
        -Verbose

    # Runs in task scheduler by gMSA (rather remove comment for -Verbose -Debug when debugging locally)
    Start-CheckIDPasswordAgentListener -Sleep 2 # -Verbose -Debug
}
#endregion

#region Stop scheduled task switch
else {
    try {
        if ($StopTask) {
            Write-Verbose "Waiting for $WaitToStopTaskInSeconds seconds and then trying to stop CheckIDPasswordAgent task within an allowed graceful interval of $GraceSeconds seconds"
            Write-EventLog -LogName "Application" -Source "CheckIDPasswordAgent" -EventId 1007 -EntryType Information -Message "Waiting for $WaitToStopTaskInSeconds seconds and then trying to stop CheckIDPasswordAgent listener within $GraceSeconds seconds." -ErrorAction Continue
            Start-Sleep -Seconds $WaitToStopTaskInSeconds
        }
        Write-Verbose "Trying to stop CheckIDPasswordAgent task within an allowed graceful interval of $GraceSeconds seconds"
        Write-EventLog -LogName "Application" -Source "CheckIDPasswordAgent" -EventId 1007 -EntryType Information -Message "Trying to stop CheckIDPasswordAgent listener within $GraceSeconds seconds." -ErrorAction Continue
        
        Write-Verbose "Stopping scheduled task '$TaskName'..."
        Stop-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    
        # Wait for the task to no longer be in state 'Running', maximum of GraceSeconds
        $deadline = (Get-Date).AddSeconds([Math]::Max(5, $GraceSeconds))
        do {
            Start-Sleep -Seconds 2
            $info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction Stop
            if ($info.State -ne 'Running') {
                Write-Verbose "Successfully stopped CheckIDPasswordAgent listener"
                Write-EventLog -LogName "Application" -Source "CheckIDPasswordAgent" -EventId 1009 -EntryType Information -Message "Successfully stopped CheckIDPasswordAgent listener." -ErrorAction Continue
                break
            }
        }
        while ((Get-Date) -lt $deadline)
    }
    catch {
        Write-EventLog -LogName "Application" -Source "CheckIDPasswordAgent" -EventId 1207 -EntryType Error -Message "Could not stop scheduled task '$TaskName'." -ErrorAction Continue
        Write-Error -Message "Failed to stop scheduled task: $_"
    }
}
#endregion