param vnetName string
param pesubnetName string

param region string
param svcname string
param svctype string
param zonename string
param groupId string

var pename = '${svcname}-${groupId}-pe'
var peNicName = '${pename}-nic'
var svcid = resourceId(svctype, svcname)

resource privateZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: zonename
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: vnetName

  resource pesubnet 'subnets' existing = {
    name: pesubnetName
  }
}

resource svcPe 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: pename
  location: region
  
  properties: {
    privateLinkServiceConnections: [
      {
        name: pename
        properties: {
          privateLinkServiceId: svcid
          groupIds: [groupId]
        }
      }
    ]
    customNetworkInterfaceName: peNicName
    subnet: {
      id: vnet::pesubnet.id
    }
  }

  resource pdzGroup 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: privateZone.id
          }
        }
      ]
    }
  }
}
