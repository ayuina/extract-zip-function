param prefix string = 'ayuina0215b'
param region string = 'westus3'

var runFromPackageUrl = 'https://ayuinacloudsharestorages.blob.core.windows.net/contents/publish.zip?sp=r&st=2023-02-17T20:13:05Z&se=2023-03-31T04:13:05Z&spr=https&sv=2021-06-08&sr=b&sig=GeKF0vuX308FD6ajCUN4Tz32jdHlrcaOd2L8QgcW37U%3D'
//var runFromPackageUrl = 'https://github.com/ayuina/extract-zip-function/releases/download/app-v1/publish.zip'
//var funcSrcRepoUrl = 'https://github.com/ayuina/extract-zip-function.git'

module infra './infrastructure.bicep' = {
  name: 'infra'
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
    vnetName: infra.outputs.vnetName
    funcsubnetName: infra.outputs.funcsubnetName
    pesubnetName: infra.outputs.pesubnetName
    funcStrName: infra.outputs.funcStrName
    dataStrName: infra.outputs.dataStrName
    runFromPackageUrl: runFromPackageUrl
  }
}

// module appplication './bindings.bicep' = {
//   name: 'bindings'
//   params: {
//     region: region
//     funcAppName: platform.outputs.funcAppName
//     dataStrName: platform.outputs.dataStrName
//   }
// }
