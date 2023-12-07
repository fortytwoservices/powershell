# Invoke-roleAssignments.ps1
# Assign necessary roles to the resources

$resourceGroupName = Get-AutomationVariable -Name 'resourceGroupName'
$managedIdentityClientId = Get-AutomationVariable -Name 'managedIdentityClientId'
$entraIdAdminsGroupObjectId = Get-AutomationVariable -Name 'entraIdAdminsGroupObjectId'
$entraIdUsersGroupObjectId = Get-AutomationVariable -Name 'entraIdUsersGroupObjectId'

# Connect to Azure with user-assigned managed identity, ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process
$AzureContext = (Connect-AzAccount -Identity -AccountId $managedIdentityClientId).context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext

# Get the resource group id
$resourceGroup = (Get-AzResourceGroup -Name $resourceGroupName).ResourceId
Write-Output "Assigning roles to resources in resource group: $($resourceGroup)"

try {
    # Allow groups to see the AVD Application Group
    New-AzRoleAssignment -RoleDefinitionName "Desktop Virtualization User" -ObjectID $entraIdAdminsGroupObjectId -Scope $resourceGroup
    New-AzRoleAssignment -RoleDefinitionName "Desktop Virtualization User" -ObjectID $entraIdUsersGroupObjectId -Scope $resourceGroup

    # Allow members of Admins group to login to VM as admin, Operate backups and power on/off VM
    New-AzRoleAssignment -RoleDefinitionName "Virtual Machine Administrator Login" -ObjectID $entraIdAdminsGroupObjectId -Scope $resourceGroup
    New-AzRoleAssignment -RoleDefinitionName "Desktop Virtualization Power On Off Contributor" -ObjectID $entraIdAdminsGroupObjectId -Scope $resourceGroup
    New-AzRoleAssignment -RoleDefinitionName "Backup Operator" -ObjectID $entraIdAdminsGroupObjectId -Scope $resourceGroup

    # Allow members of Users group to login to VM as user
    New-AzRoleAssignment -RoleDefinitionName "Virtual Machine User Login" -ObjectID $entraIdUsersGroupObjectId -Scope $resourceGroup
}
catch {
    Write-Error "An error occurred while assigning roles: $_"
}