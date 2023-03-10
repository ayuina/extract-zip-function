param prefix string
param region string
param vnetaddressPrefix24 string

var vnetRootRange24 = vnetaddressPrefix24
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

var funcStrName = '${replace(prefix, '-', '')}funcstr'
var dataStrName = '${replace(prefix, '-', '')}datastr'
var dataStrTopicName = '${dataStrName}-topic'


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

resource funcStr 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: funcStrName
  location: region
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
    }
  }
}

resource dataStr 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: dataStrName
  location: region
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}



module blobPe './privateEndpoint.bicep' = {
  name: 'funcstr-blob-pe'
  params:{
    region: region
    svcname: funcStr.name
    svctype: funcStr.type
    zonename: blobPrivateZone.name
    groupId: 'blob'
    vnetName: vnetName
    pesubnetName: pesubnetName
  }
}

module queuePe './privateEndpoint.bicep' = {
  name: 'funcstr-queue-pe'
  params:{
    region: region
    svcname: funcStr.name
    svctype: funcStr.type
    zonename: queuePrivateZone.name
    groupId: 'queue'
    vnetName: vnetName
    pesubnetName: pesubnetName
  }
}

module tablePe './privateEndpoint.bicep' = {
  name: 'funcstr-table-pe'
  params:{
    region: region
    svcname: funcStr.name
    svctype: funcStr.type
    zonename: tablePrivateZone.name
    groupId: 'table'
    vnetName: vnetName
    pesubnetName: pesubnetName
  }
}

module filePe './privateEndpoint.bicep' = {
  name: 'funcstr-file-pe'
  params:{
    region: region
    svcname: funcStr.name
    svctype: funcStr.type
    zonename: filePrivateZone.name
    groupId: 'file'
    vnetName: vnetName
    pesubnetName: pesubnetName
  }
}

module dataBlobPe './privateEndpoint.bicep' = {
  name: 'datastr-blob-pe'
  params:{
    region: region
    svcname: dataStr.name
    svctype: dataStr.type
    zonename: blobPrivateZone.name
    groupId: 'blob'
    vnetName: vnetName
    pesubnetName: pesubnetName
  }
}

module dataQueuePe './privateEndpoint.bicep' = {
  name: 'datastr-queue-pe'
  params:{
    region: region
    svcname: dataStr.name
    svctype: dataStr.type
    zonename: queuePrivateZone.name
    groupId: 'queue'
    vnetName: vnetName
    pesubnetName: pesubnetName
  }
}

resource topic 'Microsoft.EventGrid/systemTopics@2022-06-15' = {
  name: dataStrTopicName
  location: region
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    source: dataStr.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}


resource queueSenderRoleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'c6a89b2d-59bc-44d0-9896-0f6e12d7b80a'
}

resource queueSenderAssign 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: dataStr
  name: guid(dataStr.id, topic.id, queueSenderRoleDef.id)
  properties:{
    roleDefinitionId: queueSenderRoleDef.id
    principalType: 'ServicePrincipal'
    principalId: topic.identity.principalId
  }
}


output vnetName string = vnetName
output pesubnetName string = pesubnetName
output funcsubnetName string = funcsubnetName
output funcStrName string = funcStrName
output dataStrName string = dataStrName
output dataStrTopicName string = dataStrTopicName
