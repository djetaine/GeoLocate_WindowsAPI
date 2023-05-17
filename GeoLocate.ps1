#Turn on Location Services if not already on.

# Function to set the registry value if it is "Deny" or does not exist
function Set-RegistryValueIfDenied {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Value
    )

    $currentValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $currentValue -or $currentValue.$Name -eq "Deny") {
        Set-ItemProperty -Path $Path -Name $Name -Value $Value
        Write-Output "Updated $Path\$Name to $Value"
    } else {
        Write-Output "$Path\$Name is already set to $($currentValue.$Name)"
    }
}


# These set the "Location Services enabled" to On while still prompting the user to turn on for modern apps.
Set-RegistryValueIfDenied -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Allow"
Set-RegistryValueIfDenied -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Allow"

#This sets the "Location Services enabled" to "On" for Desktop apps (which allows our powershell script to access UWM)
Set-RegistryValueIfDenied -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\NonPackaged" -Name "Value" -Value "Allow"

#Get Location Namespace
Add-Type -AssemblyName System.Device 

#Create GeoLocate object from UWM
$GeoLocationLatLong = New-Object System.Device.Location.GeoCoordinateWatcher 

#Find Location using available options (GPS if available or WiFi positioning. Basically whatever windows has access to
$GeoLocationLatLong.Start() 

#Give time to pull the location. Without the wait it will fail immediately.Also check to verify the user running has permission to access.  
while (($GeoLocationLatLong.Status -ne 'Ready') -and ($GeoLocationLatLong.Permission -ne 'Denied')) {
    Start-Sleep -Milliseconds 100 
}

if ($GeoLocationLatLong.Permission -eq 'Denied'){
    Write-Error 'Access Denied. Did function Set-RegistryValueIfDenied run? '
} else {
    $latitude = $GeoLocationLatLong.Position.Location.Latitude
    $longitude = $GeoLocationLatLong.Position.Location.Longitude

#-----------------------------------------------------------------------------------------
# USE OpenCage API to get street address
# Comment this block if you dont need a street address or want to use Google Maps instead
$apiKey = '<your OpenCage API Key>' # Replace with your OpenCage API key
$url = "https://api.opencagedata.com/geocode/v1/json?q=$latitude+$longitude&key=$apiKey"

    $response = Invoke-RestMethod -Uri $url

    if ($response.status.code -eq 200) {
        $address = $response.results[0].formatted
        Write-Output "Address: $address"
    } else {
        Write-Error 'Failed to retrieve address'
    }
}
$GoogleMapsLink = "https://www.google.com/maps/@$latitude,$longitude,15z"
#End OpenCage Address query
#----------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------
#Use Google Maps API to pull street Address
#Comment this block if you dont need street address or want to use OpenCage instead
#$apiKey = "YOUR_API_KEY"  # Replace with your Google Maps API key

# Build the URL for the Geocoding API request
#$apiUrl = "https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$apiKey"

# Send the HTTP request to the Geocoding API
#$response = Invoke-RestMethod -Uri $apiUrl -Method Get

# Extract the address and Google Maps link from the API response
#$address = $response.results[0].formatted_address
#$googleMapsLink = $response.results[0].url
#----------------------------------------------------------------------------------------

# Uncomment this if you use this script in conjunction with NinjaRMM
# The following updates a custom field in NinjaRMM to display the address and create a link to google maps. 
# Create this custom field in Administration > Devices > Global Custom Fields with the Name matching the name here. 
# Address is a Text Field type, Url is a URL Field type.
# Once created set the technician field to Read Only and the Scripts field to Write. Set to Read/Write if you plan on using this value in further scripts. 

Ninja-Property-Set -name Address -value $Address
Ninja-Property-Set -name GoogleMapsurl -value $GoogleMapsLink
