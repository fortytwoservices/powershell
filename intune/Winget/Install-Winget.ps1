# Install the Winget package

# Check if we are elevated
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script needs to be run with elevated privileges"
    Exit 1
}

# Check if winget is already installed
$CustomScripts = $(Join-Path $env:ProgramData CustomScripts)
if (!(Test-Path $CustomScripts)) {
    Write-Verbose "Creating $CustomScripts"
    New-Item -Path $CustomScripts -ItemType Directory -Force -Confirm:$false
}

#Check Winget Install
Write-Verbose "Checking if Winget is installed"
$TestWinget = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq "Microsoft.DesktopAppInstaller" } -Verbose:$false
If ([Version]$TestWinGet.Version -gt "2022.506.16.0") {
    Write-Verbose "WinGet is already installed.."
}
Else {
    #Download WinGet MSIXBundle
    Write-Verbose "Not installed. Downloading WinGet..."
    $WinGetURL = "https://aka.ms/getwinget"
    (New-Object System.Net.WebClient).DownloadFile($WinGetURL, "$CustomScripts\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle") | Out-Null

    #Install WinGet MSIXBundle
    Try {
        Write-Verbose "Installing Winget..."
        Add-AppxProvisionedPackage -Online -PackagePath "$CustomScripts\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -SkipLicense
        Write-Verbose "Installed Winget"
    }
    Catch {
        Write-Error "Installation of Winget FAILED..."
        Exit 1
    }
}