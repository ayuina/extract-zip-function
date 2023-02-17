param prefix string = 'ayuina0215b'
param region string = 'westus3'

module network 'networking.bicep' = {
  name: 'network'
  params: {
    prefix: prefix
    region: region
  }
}

module platform './platform.bicep' = {
  name: 'platform'
  params: {
    prefix: prefix
    region: region
    vnetName: network.outputs.vnetName
    funcsubnetName: network.outputs.funcsubnetName
    pesubnetName: network.outputs.pesubnetName
  }
}

module appplication './bindings.bicep' = {
  name: 'bindings'
  params: {
    prefix: prefix
    region: region
    funcAppName: platform.outputs.funcAppName
    vnetName: platform.outputs.vnetName
    pesubnetName: platform.outputs.pesubnetName
  }
}
