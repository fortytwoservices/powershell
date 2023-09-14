[CmdletBinding()]
param (
    [Parameter()]
    [String]
    $TenantId
)

$NodeImageVersions = @()
$Clusters = @()

if (!$TenantId) {
    $Clusters = Get-AzAksCluster
} else {
    $AllSubscriptions = Get-AzSubscription -TenantId $TenantId | Where-Object { $_.State -eq 'Enabled' }
    $i = 0
    foreach ($Subscription in $AllSubscriptions) {
        $i++
        $Completed = ($i/$AllSubscriptions.Count)*100
        Write-Progress -Activity "Finding all Kubernetes clusters" -Status "Progress:" -PercentComplete $Completed
        $Clusters += Get-AzAksCluster -Subscription $Subscription.Id
    }
}

$Clusters | ForEach-Object -Begin {
    Write-Host "Checking node image versions for $($Clusters.Count) clusters..."
} -Process {
    $ImageVersions = $Cluster.AgentPoolProfiles.NodeImageVersion | Sort-Object -Unique
    $NodeImageVersions += [PSCustomObject]@{
        ClusterName = $Cluster.Name
        NodeImageVersions = $ImageVersions
    }
}

$NodeImageVersions | Format-Table -AutoSize