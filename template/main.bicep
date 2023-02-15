param prefix string = 'ayuina0215b'
param region string = 'westus3'



module platform './platform.bicep' = {
  name: 'platforn'
  params: {
    prefix: prefix
    region: region
  }
}

module appplication 'func.bicep' = {
  name: 'func'
  params: {
    prefix: prefix
    region: region
    funcAppName: platform.outputs.funcAppName
  }
}
