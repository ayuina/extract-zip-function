param prefix string
param region string

var vnetRootRange24 = '10.0.0'
var vnetName = '${prefix}-vnet'
var vnetRange = '${vnetRootRange24}.0/24'
var pesubnetName = 'private-endpoint-subnet'
var pesubnetRange = '${vnetRootRange24}.0/26'
var funcsubnetName = 'functions-subnet'
var funcsubnetRange = '${vnetRootRange24}.64/26'

var appsvcZoneName = 'privatelink.azurewebsites.net'
var blobZoneName = 'privatelink.blob.${environment().suffixes.storage}'
var queueZoneName = 'privatelink.queue.${environment().suffixes.storage}'
var tableZoneName = 'privatelink.table.${environment().suffixes.storage}'
var fileZoneName = 'privatelink.file.${environment().suffixes.storage}'

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vnetName
  location: region
  properties:{
    addressSpace: {
      addressPrefixes:[
        vnetRange
      ]
    }
    subnets:[
      {
        name: pesubnetName
        properties:{
          addressPrefix: pesubnetRange
        }
      }
      {
        name: funcsubnetName
        properties:{
          addressPrefix: funcsubnetRange
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }

  resource pesubnet 'subnets' existing = {
    name: pesubnetName
  }
  resource funcsubnet 'subnets' existing = {
    name: funcsubnetName
  }
}

resource appsvcPrivateZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: appsvcZoneName
  location: 'global'

  resource zoneLink 'virtualNetworkLinks' = {
    name: 'appsvcZone-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

resource blobPrivateZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: blobZoneName 
  location: 'global'

  resource zoneLink 'virtualNetworkLinks' = {
    name: 'blobZone-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

resource queuePrivateZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: queueZoneName
  location: 'global'

  resource zoneLink 'virtualNetworkLinks' = {
    name: 'queueZone-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

resource tablePrivateZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: tableZoneName
  location: 'global'

  resource zoneLink 'virtualNetworkLinks' = {
    name: 'tableZone-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

resource filePrivateZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: fileZoneName
  location: 'global'

  resource zoneLink 'virtualNetworkLinks' = {
    name: 'fileZone-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

output vnetName string = vnetName
output pesubnetName string = pesubnetName
output funcsubnetName string = funcsubnetName

