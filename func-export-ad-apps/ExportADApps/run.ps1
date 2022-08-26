param($Timer)

####################################################################################################
#
# Retrieves a list of all AD Apps that the managed identity for this function app has access to,
# and then exports this list of apps, with owners and non-sensitive key and secret data, to blob file.
# Optionally, export AD Apps with expired secrets or certificates to a seperate blob file.
#
####################################################################################################

# Initialise variables
$TenantID = $env:TenantID
$runInAzureFunction = $true
$exportExpiredApps = $true
$expiryMarginInDays = 30 # the number of days, relative to today, within which a soon to expire app will be included in the expired app list

# Derived variables
$expiryDateThreshold = (Get-date).AddDays($expiryMarginInDays)
$myApps = New-Object System.Collections.ArrayList
$expiredApps = New-Object System.Collections.ArrayList

# Login and get the context
if ($runInAzureFunction) {
    $token = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com" -TenantId $TenantID
    Connect-MgGraph -AccessToken $token.Token
} else {
    Connect-MgGraph -Scopes 'Application.Read.All','User.ReadBasic.All' -TenantId $TenantID
}

# Get list of all applications
$apps = Get-MgApplication

# Loop over each application and extract the required info
foreach ($app in $apps) 
{
    Write-Host $app.Id - $app.DisplayName

    # Assume this does not need to be exported as an expired app
    $exportAsExpiredApp = $false

    # Start with basic app info
    $temp = "" | Select "ApplicationID", "ApplicationName", "ObjectID", "Owners", "Credentials"
    $temp.ApplicationID = $app.AppId
    $temp.ApplicationName = $app.DisplayName
    $temp.ObjectID = $app.Id

    # Get app owners
    $owners = Get-MgApplicationOwner -ApplicationId $app.Id 
    $appOwners = New-Object System.Collections.ArrayList
    if ($owners.Count -ne 0)
    {

        foreach ($owner in $owners) 
        {
            $ownerAad = Get-MgUser -UserId $owner.Id -ErrorAction SilentlyContinue
            if ($ownerAad -ne $null)
            {
                $tempOwner = "" | Select "ObjectId", "UserPrincipalName", "Mail"
                $tempOwner.ObjectId = $owner.Id
                $tempOwner.UserPrincipalName = $ownerAad.UserPrincipalName
                $tempOwner.Mail = $ownerAad.Mail
                $appOwners.Add($tempOwner) | Out-Null
            }
        }
    }
    $temp.Owners = $appOwners

    # Store certificates and secrets in one array
    $appCredentials = New-Object System.Collections.ArrayList

    # Get app certificates
    foreach ($certificate in $app.KeyCredentials) 
    {
        $tempCertificate = "" | Select "Type", "Id", "StartDateTime", "EndDateTime", "Name"
        $tempCertificate.Type = "Certificate"
        $tempCertificate.Id = $certificate.KeyId
        $tempCertificate.Name = $certificate.DisplayName
        $tempCertificate.StartDateTime = $certificate.StartDateTime
        $tempCertificate.EndDateTime = $certificate.EndDateTime
        $appCredentials.Add($tempCertificate) | Out-Null

        # Check if this needs to be exported as an expired app, and has not already been included
        if ($exportExpiredApps -and $exportAsExpiredApp -eq $false -and $tempCertificate.EndDateTime -le $expiryDateThreshold) {
            $exportAsExpiredApp = $true
        }
    }

    # Get app secrets
    foreach ($secret in $app.PasswordCredentials) 
    {
        $tempSecret = "" | Select "Type", "Id", "StartDateTime", "EndDateTime", "Name"
        $tempSecret.Type = "Secret"
        $tempSecret.Id = $secret.KeyId
        $tempSecret.Name = $secret.DisplayName
        $tempSecret.StartDateTime = $secret.StartDateTime
        $tempSecret.EndDateTime = $secret.EndDateTime
        $appCredentials.Add($tempSecret) | Out-Null

        # Check if this needs to be exported as an expired app, and has not already been included
        if ($exportExpiredApps -and $exportAsExpiredApp -eq $false -and $tempSecret.EndDateTime -lt $expiryDateThreshold) {
            $exportAsExpiredApp = $true
        }

    }

    # Add the credentials to the app, and app data object to the list of apps
    $temp.Credentials = $appCredentials 
    $myApps.Add($temp) | Out-Null

    # Add the app data object to the list of expired apps, if applicable
    if ($exportAsExpiredApp) {
        $expiredApps.Add($temp) | Out-Null
    }
}

# Log completion
Write-Host ("AD App Processing completed. " + $myApps.Count + " applications found.")
if ($exportExpiredApps) {
    Write-Host (" - " + $expiredApps.Count + " aplications with expired, or soon to expire, credentials found.")
}

Push-OutputBinding -Name outputBlobAllApps -Value $myApps
Push-OutputBinding -Name outputBlobExpiredApps -Value $expiredApps