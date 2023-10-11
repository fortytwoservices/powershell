<#
.SYNOPSIS
    This script retrieves the node image versions for all AKS clusters in a subscription or across all subscriptions.

.PARAMETER SubscriptionId
    The ID of the subscription to retrieve AKS clusters from.

.PARAMETER TenantId
    The ID of the tenant to retrieve AKS clusters from.

.PARAMETER Name
    The name of the AKS cluster to retrieve.

.PARAMETER ResourceGroupName
    The name of the resource group containing the AKS cluster to retrieve.

.PARAMETER AllSubscriptions
    If specified, retrieves AKS clusters from all subscriptions.

.OUTPUTS
    Returns an array of objects containing the name of the AKS cluster, the subscription it belongs to, and an array of node image versions.

.EXAMPLE
    PS C:\> .\NodeImageChecker.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012"

    Retrieves the node image versions for all AKS clusters in the specified subscription.

.EXAMPLE
    PS C:\> .\NodeImageChecker.ps1 -AllSubscriptions

    Retrieves the node image versions for all AKS clusters across all subscriptions.

#>

[CmdletBinding()]
param (
    [Parameter()]
    [String]
    $SubscriptionId,
    [Parameter()]
    [String]
    $TenantId,
    [Parameter()]
    [String]
    $Name,
    [Parameter()]
    [String]
    $ResourceGroupName,
    [Parameter()]
    [Switch]
    $AllSubscriptions
)

$NodeImageVersions = @()
$Clusters = @()

if ($TenantId) {
    $Subscriptions = Get-AzSubscription -TenantId $TenantId | Where-Object { $_.State -eq 'Enabled' }
    $i = 0
    foreach ($Subscription in $Subscriptions) {
        $i++
        $Completed = ($i/$Subscriptions.Count)*100
        Write-Progress -Activity "Finding all Kubernetes clusters, subscription $i of $($Subscriptions.count)" -Status "Progress:" -PercentComplete $Completed
        $Clusters += Get-AzAksCluster -Subscription $Subscription.Id
    }
} elseif ($SubscriptionId) {
    $Clusters += Get-AzAksCluster -Subscription $SubscriptionId
} elseif ($ClusterName) {
    $Clusters += Get-AzAksCluster -Name $ClusterName
} elseif ($AllSubscriptions) {
    $Subscriptions = Get-AzSubscription | Where-Object { $_.State -eq 'Enabled' }
    $i = 0
    foreach ($Subscription in $Subscriptions) {
        $i++
        $Completed = ($i/$Subscriptions.Count)*100
        Write-Progress -Activity "Finding all Kubernetes clusters, subscription $i of $($Subscriptions.count)" -Status "Progress:" -PercentComplete $Completed
        $Clusters += Get-AzAksCluster -Subscription $Subscription.Id
    }
} else {
    $Clusters += Get-AzAksCluster
}

foreach ($Cluster in $Clusters) {
    $ImageVersions = $Cluster.AgentPoolProfiles.NodeImageVersion | Sort-Object -Unique
    $NodeImageVersions += [PSCustomObject]@{
        ClusterName = $Cluster.Name
        Subscription = $Cluster.Id.Split('/')[2]
        NodeImageVersions = $ImageVersions
    }
}

return $NodeImageVersions