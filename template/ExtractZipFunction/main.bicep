param prefix string = 'ayuina0215b'
param region string = 'westus3'

module platform './platform.bicep' = {
  name: 'platfornm'
  params: {
    prefix: prefix
    region: region
  }
}

module appplication 'bindings.bicep' = {
  name: 'bindings'
  params: {
    prefix: prefix
    region: region
    funcAppName: platform.outputs.funcAppName
  }
}
