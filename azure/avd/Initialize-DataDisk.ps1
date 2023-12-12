# Script to initialize and format the datadisk

$driveLetter = "E"

Write-Host -ForegroundColor DarkGreen "Initializing and formatting the datadisk as drive $driveLetter"
# Initialize the disk
try {
    Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' } |
    Initialize-Disk -PartitionStyle GPT -PassThru |
    New-Partition -DriveLetter $driveLetter -UseMaximumSize |
    Format-Volume -FileSystem NTFS -NewFileSystemLabel 'Datadisk' -Confirm:$false
} catch {
    # Handle the exception
    Write-Error "An error occurred: $_"
}


