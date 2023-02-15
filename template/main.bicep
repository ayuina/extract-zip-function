param prefix string = 'ayuina0215b'
param region string = 'westus3'

var funcStrName = '${prefix}funcstr'
var logAnalyticsName = '${prefix}-laws'
var appInsightsName = '${prefix}-ai'
var funcAppName = '${prefix}-func'
var funcPlanName = '${prefix}-func-plan'

var dataStrName = '${prefix}datastr'
var uploadContainerName = 'archive-upload'
var extractedContainerName = 'archive-extracted'

module platform './platform.bicep' = {
  name: 'platforn'
  params: {
    region: region
    funcStrName: funcStrName
    logAnalyticsName: logAnalyticsName
    appInsightsName: appInsightsName
    funcAppName: funcAppName
    funcPlanName: funcPlanName
  }
}

resource dataStr 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: dataStrName
  location: region
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource blobSvc 'Microsoft.Storage/storageAccounts/blobServices@2022-05-01' existing = {
  name: 'default'
  parent: dataStr
}

resource uploadContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: uploadContainerName
  parent: blobSvc
  properties: {
    publicAccess: 'None'
  }
}

resource extractedContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: extractedContainerName
  parent: blobSvc
  properties: {
    publicAccess: 'None'
  }
}

resource funcApp 'Microsoft.Web/sites@2022-03-01' existing = {
  name: funcAppName
}

resource config 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: funcApp
  name: 'appsettings'
  properties:{
    Project: 'src'
  }
}

// resource source 'Microsoft.Web/sites/sourcecontrols@2022-03-01' = {
//   parent: funcApp
//   name: 'web'
//   properties: {
//     repoUrl: 'https://github.com/ayuina/extract-zip-function.git'
//     branch: 'main'
//     isManualIntegration: true
//   }
//   dependsOn:[config]
// }
