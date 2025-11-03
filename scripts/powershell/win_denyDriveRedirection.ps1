# Set the registry path and property value
$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
$propertyName = "fDisableCdm"
$propertyValue = 1  # 1: Disable drive redirection

# Create the registry path if it does not exist
if (-not (Test-Path $registryPath)) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT" -Name "Terminal Services" -Force
    Write-Host "Created registry path: $registryPath"
}

# Check if the fDisableCdm property exists
$existingProperty = Get-ItemProperty -Path $registryPath -Name $propertyName -ErrorAction SilentlyContinue

if ($null -ne $existingProperty) {
    # If the property exists, update it
    Set-ItemProperty -Path $registryPath -Name $propertyName -Value $propertyValue
    Write-Host "Updated '$propertyName' to $propertyValue."
} else {
    # If the property does not exist, create it
    New-ItemProperty -Path $registryPath -Name $propertyName -Value $propertyValue -PropertyType DWORD -Force
    Write-Host "Created '$propertyName' with value $propertyValue."
}

# Force a Group Policy update
gpupdate /force
Write-Host "Group Policy update has been forced."
