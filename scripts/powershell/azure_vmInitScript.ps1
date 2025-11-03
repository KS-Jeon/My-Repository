# 1. Azure Login
Write-Host "Login into Azure..."
Connect-AzAccount

# 2. Retrieve Host Pool and Session Hosts
$resourceGroup = Read-Host "Enter the resource group name of the session hosts"
$hostPoolName = Read-Host "Enter host pool name"

Write-Host "Retrieving session hosts list in host pool '$hostPoolName'..."
$sessionHosts = Get-AzWvdSessionHost -ResourceGroupName $resourceGroup -HostPoolName $hostPoolName

if ($sessionHosts.Count -eq 0) {
    Write-Host "No session hosts found in host pool '$hostPoolName'."
    exit
}

# 3. Drive Redirection Option Selection
$driveOption = Read-Host "Enter 'allow' to permit drive redirection on the VM, or 'deny' to disallow"
if ($driveOption -eq "allow") {
    $scriptName = "allowDriveRedirection.ps1"
} elseif ($driveOption -eq "deny") {
    $scriptName = "denyDriveRedirection.ps1"
} else {
    Write-Host "Invalid input. Using default 'deny'."
    $scriptName = "denyDriveRedirection.ps1"
}

# 4. Input Storage Account and Container Information
$storageAccountRG = Read-Host "Enter the resource group name of the storage account"
$storageAccountName = Read-Host "Enter storage account name"
$containerName = Read-Host "Enter container name"

# Retrieve storage account key
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $storageAccountRG -Name $storageAccountName)[0].Value

# Calculate the expiry date (using a DateTime object)
$expiryDate = (Get-Date).AddDays(1).ToUniversalTime()

# Create the storage account context using the storage account key
$context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageKey

# Generate a SAS token for the specified container with read permission (HTTPS only)
$sasToken = New-AzStorageContainerSASToken -Name $containerName -Context $context -Permission "r" -ExpiryTime $expiryDate -Protocol HttpsOnly -FullUri:$false

# Prepend '?' to the SAS token if not already present
if (-not $sasToken.StartsWith('?')) {
    $sasToken = "?" + $sasToken
}

# Construct script URL
$scriptUrl = "https://$storageAccountName.blob.core.windows.net/$containerName/$scriptName$sasToken"

Write-Host "Selected option: $driveOption, script to execute: $scriptName"
Write-Host "Generated script URL: $scriptUrl"

# 5. For each session host VM, start and execute the extension script sequentially
Write-Host "Starting VMs and executing extension script on each session host..."

$settings = @{
    fileUris = @($scriptUrl)
    commandToExecute = "powershell.exe -ExecutionPolicy Unrestricted -File .\$scriptName"
}

foreach ($sessionHost in $sessionHosts) {
    $vmNameParts = $sessionHost.Name.Split('/')
    $vmName = $vmNameParts[-1]
    
    Write-Host "Session host VM: $sessionHost.Name"
    Write-Host "Starting VM: $vmName"
    Start-AzVM -Name $vmName -ResourceGroupName $resourceGroup

    Write-Host "Executing extension script on: $vmName"
        Set-AzVMExtension `
        -ResourceGroupName $resourceGroup `
        -VMName $vmName `
        -Name "UpdateDriveRedirection" `
        -Publisher "Microsoft.Compute" `
        -ExtensionType "CustomScriptExtension" `
        -TypeHandlerVersion "1.10" `
        -Settings $settings
    
    do {
        Start-Sleep -Seconds 5
        $currentExtension = Get-AzVMExtension -ResourceGroupName $resourceGroup -VMName $vmName -Name "UpdateDriveRedirection"
        Write-Host "Current status: $($currentExtension.ProvisioningState)"
    } while ($currentExtension.ProvisioningState -ne "Succeeded" -and $currentExtension.ProvisioningState -ne "Failed")
    
    if ($currentExtension.ProvisioningState -eq "Succeeded") {
        Write-Host "Extension script executed successfully on: $vmName"
    }
    else {
        Write-Host "Extension script execution failed on: $vmName - Status: $($currentExtension.ProvisioningState)"
    }
    
    Write-Host "Stopping VM: $vmName"
    Stop-AzVM -Name $vmName -ResourceGroupName $resourceGroup -Force
}