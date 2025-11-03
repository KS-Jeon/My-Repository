param vmCount string   
param vmNameNum string 
param vmOSName string                      
param location string                     
param adminUsername string                
@secure()
param adminPassword string                
param hostPoolName string
param artifactsLocation string
param aadJoin string
param existingVnetName string              
param existingSubnetName string
param resourceLocation string = resourceGroup().location
param hostPoolProperties object = {
  registrationInfo: { 
    expirationTime: dateTimeAdd(utcNow(), 'P30D')         
    registrationTokenOperation: 'Update'   
  }                            
}
param domainToJoin string 
param domainadminUser string 
param ouPath string 
param domainJoinOptions string
@secure()
param DomainPassword string 

var aadJoinBool = toLower(aadJoin) == 'true'
var vmNum = int(vmCount)
var domainJoinOptionsNum = int(domainJoinOptions)
var vmNameNumber = int(vmNameNum)

// -----------------------------------
// 사용할 Image 지정 ( 사용 시 주석 해제하여 사용 )
// -----------------------------------
/*
resource vmImage 'Microsoft.Compute/images@2024-07-01' existing = {
  name: 'image-20250123141347'
  scope: resourceGroup('AD-BICEP-RG') 
}
*/
resource existingVirtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: existingVnetName
}

resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: existingVirtualNetwork
  name: existingSubnetName
}

resource miAVD 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: 'MI-Test-AVD'
}

// -----------------------------------
// AVD Personal 호스트 풀 생성
// -----------------------------------
resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' = {
  name: hostPoolName
  location: location
  properties: hostPoolProperties                               
}
// -----------------------------------
// Network Interface (NIC) 생성
// -----------------------------------
resource nics 'Microsoft.Network/networkInterfaces@2021-05-01' = [for i in range(0, vmNum): {
  name: '${hostPoolName}-${vmOSName}${i+vmNameNumber}-nic'
  location: resourceLocation
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: existingSubnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}]

// -----------------------------------
// Virtual Machines 생성
// -----------------------------------
resource vms 'Microsoft.Compute/virtualMachines@2024-03-01' = [for i in range(0, vmNum): {
  name: '${hostPoolName}-${vmOSName}${i+vmNameNumber}'
  location: resourceLocation
  identity: aadJoin == 'true' 
  ? {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${miAVD.id}': {}
    }
  } 
  : {
    type: 'None'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_F4s_v2'
    }
    osProfile: {
      computerName: '${vmOSName}${i+vmNameNumber}'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsdesktop'
        offer: 'windows-11'
        sku: 'win11-24h2-ent'
        version: 'latest'
      }
      osDisk: {
        name: '${hostPoolName}-${vmOSName}${i+vmNameNumber}-OsDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nics[i].id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
  }
}]
// -----------------------------------
// VM 무결성 모니터링 실행 스크립트
// -----------------------------------
resource guestAttestation 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = [for i in range(0, vmNum): {
  parent: vms[i]
  name: 'GuestAttestation'
  location: resourceLocation
  properties: {
    publisher: 'Microsoft.Azure.Security.WindowsAttestation'
    type: 'GuestAttestation'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      AttestationConfig: {
        MaaSettings: {
          maaEndpoint: ''
          maaTenantName: 'GuestAttestation'
        }
        AscSettings: {
          ascReportingEndpoint: ''
          ascReportingFrequency: ''
        }
        useCustomToken: 'false'
        disableAlerts: 'false'
      }
    }
  }
}]
// -----------------------------------
// Domain Join (EntraID) 스크립트
// -----------------------------------
resource entraIdJoin 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = [for i in range(0, vmNum):if(aadJoin == 'true') {
  parent: vms[i]
  name: 'EntraIDJoinExtenstion'
  location: resourceLocation
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: false
  }
  dependsOn: [
    guestAttestation
  ]
}]

// -----------------------------------
// Domain Join (WindowsAD) 스크립트
// -----------------------------------
resource WindowsADJoin 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = [for i in range(0, vmNum):if(aadJoin  == 'false') {
  parent: vms[i]
  name: 'WindowsADExtenstion'
  location: resourceLocation
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      name: domainToJoin
      ouPath: ouPath
      user: '${domainToJoin}\\${domainadminUser}'
      restart: true
      options: domainJoinOptionsNum
    }
    protectedSettings: {
      Password: DomainPassword
    }
  }
  dependsOn: [
    guestAttestation
  ]
}]
// -----------------------------------
// 호스트 풀 추가 스크립트
// -----------------------------------
resource vmExtensions 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = [for i in range(0, vmNum): {
  parent: vms[i]
  name: 'HostPoolSessionHostJoin'
  location: resourceLocation
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: artifactsLocation
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostPool.name
        aadJoin: aadJoinBool
      }
    }
    protectedSettings: {
      properties: {
        registrationInfoToken: reference(hostPool.id).registrationInfo.token
      }
    }
  }
  dependsOn: [
    entraIdJoin,WindowsADJoin
  ]
}]
