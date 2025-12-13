<#
.SYNOPSIS
    This script is designed to let you know which certificates and secrets for your enterprise apps
    and app registrations will expire soon

.DESCRIPTION
    This script checks for all required modules, installs them if not present, connects to MS Graph, gets
    all the certificates and secrets for enterprise apps and app registrations and then sorts them in
    order of expiration (soonest at the top)

.NOTES
    Author: Daniel Boyle
    Date: 12/11/2025
    Version: 0.1
    Requires: PowerShell 7+ or Powershell Core on Mac/Linux
    
.LINK
    https://learn.microsoft.com/en-us/graph/
#>


### Start Code ###

# Initiate some variables
$enterpriseAppsWithCertificates = @()
$today = (Get-Date).Date

# Define required modules
$modules = @('Microsoft.Graph')

# Ensure all required modules are installed and loaded to the session
Write-Host 'Ensuring all required Powershell modules are installed and installing any that are missing' -ForegroundColor White
foreach($module in $modules){
    if(!(Get-Module $module)){
        try{
            Import-Module $module -ErrorAction Stop
            Write-Host "Module named $module found locally and imported" -ForegroundColor White
        }
        catch{
            Write-Host "Module named $module not found - Installing..." -ForegroundColor White
            try{
                Install-Module -Name $module -Scope CurrentUser -Force -ErrorAction Stop
                Write-Host "Module named $module installed successfully" -ForegroundColor Green
            }
            catch{
                Write-Host "Module named $module failed to install" -ForegroundColor Red
                Write-Host $Error[0] -ForegroundColor Red
                #Exit 1
            }
        }
    }
    
    else{
        Write-Host "Module named $module already installed and loaded"
    }
}


# Connect to Microsoft Graph
Write-Host 'Attempting to connect to MS Graph interactively' -ForegroundColor White
try{
    Connect-MgGraph -Scopes "Application.Read.All" -NoWelcome -ErrorAction Stop
    Write-Host 'Connection to MS Graph succesful' -ForegroundColor Green
}
catch{
    Write-Host 'Unable to connect to MS Graph' -ForegroundColor Red
    Write-Host $Error[0] -ForegroundColor Red
}

# Get enterprise apps
Write-Host 'Getting all enterprise applications' -ForegroundColor White
$enterpriseApps = Get-MgServicePrincipal -All -Property DisplayName, keyCredentials, preferredTokenSigningKeyThumbprint
Write-Host "$($enterpriseApps.count) enterprise apps found"

# Loop through enterprise apps to determine if app contains a certificate that will expire at some date
# If true, get appname and days left until expiration and place in PSCustomObject $enterpriseAppsWithCertificates
foreach($enterpriseApp in $enterpriseApps){
    $cert = $enterpriseApp.KeyCredentials
    if($cert){
        $expirationdate = $cert.EndDateTime.ToLocalTime()
        $daysRemaining = ($expirationdate - $today).Days
        $enterpriseAppsWithCertificates += [PSCustomObject]@{
            AppName = $enterpriseApp.DisplayName
            DaysRemaining = $daysRemaining
        }
    }
}

if($enterpriseAppsWithCertificates.count -lt 1){
    Write-Host 'No enterprise apps with certificates found' -ForegroundColor Yellow
}
else{
    Write-Host 'The following applications are the next 10 apps to expire' -ForegroundColor Yellow
    $enterpriseAppsWithCertificates = $enterpriseAppsWithCertificates | Sort-Object ExpirationDate | Select-Object -First 10
    foreach($e in $enterpriseAppsWithCertificates){
        Write-Host "$($e.AppName) will expire in $($e.DaysRemaining) days"
    }    
}


