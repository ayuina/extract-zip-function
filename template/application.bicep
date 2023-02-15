param region string
param dataStrName string
param funcAppName string

var extractedContainerName = 'archive-extracted'

var eventSourceMap = {
  eventbase_blobtrigger_container: 'archive-upload-for-eventgrid'
  standard_blobtrigger_container:'archive-upload-for-polling'
  queuetrigger_container: 'archive-upload-for-queue'
  blob_created_queue:'archive-upload-queue'
}

var funcSrcRepoUrl = 'https://github.com/ayuina/extract-zip-function.git'

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

resource uploadContainer1 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: eventSourceMap.eventbase_blobtrigger_container
  parent: blobSvc
  properties: {
    publicAccess: 'None'
  }
}
resource uploadContainer2 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: eventSourceMap.standard_blobtrigger_container
  parent: blobSvc
  properties: {
    publicAccess: 'None'
  }
}
resource uploadContainer3 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: eventSourceMap.queuetrigger_container
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

resource queueSvc 'Microsoft.Storage/storageAccounts/queueServices@2022-09-01' existing = {
  name: 'default'
  parent: dataStr
}

resource blobUploadedQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2022-09-01' = {
  parent: queueSvc
  name: eventSourceMap.blob_created_queue
}

var addtionalSettings = {
  Project: 'src'
  AzureWebJobsDataStorage: 'DefaultEndpointsProtocol=https;AccountName=${dataStrName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${dataStr.listKeys().keys[0].value}'
}

//https://github.com/Azure/azure-cli/issues/11718

module appsettings 'mergeAppSettings.bicep' = {
  name: 'appendAppSettings'
  params: {
    appName: funcAppName
    setting1: list('Microsoft.Web/sites/${funcAppName}/config/appsettings', '2022-03-01').properties
    setting2: union(addtionalSettings, eventSourceMap)
  }
}

resource source 'Microsoft.Web/sites/sourcecontrols@2022-03-01' = {
  name: '${funcAppName}/web'
  properties: {
    repoUrl: funcSrcRepoUrl
    branch: 'main'
    isManualIntegration: true
  }
}
