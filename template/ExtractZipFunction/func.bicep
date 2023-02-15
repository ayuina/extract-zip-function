param prefix string
param region string
param funcAppName string

var dataStrName = '${prefix}datastr'
var dataStrTopicName = '${dataStrName}-topic'
var funcSrcRepoUrl = 'https://github.com/ayuina/extract-zip-function.git'

var eventSourceMap = {
  eventbase_blobtrigger_container: 'archive-upload-for-eventgrid'
  standard_blobtrigger_container:'archive-upload-for-polling'
  queuetrigger_container: 'archive-upload-for-queue'
  blob_created_queue:'archive-upload-queue'
  extracted_container: 'archive-extracted'
}

var eventbase_blobtrigger_function = 'ExtractArchive'
var queueSenderRoleid = 'c6a89b2d-59bc-44d0-9896-0f6e12d7b80a'

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

resource extractedContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: eventSourceMap.extracted_container
  parent: blobSvc
  properties: {
    publicAccess: 'None'
  }
}

resource eventbase_blobtrigger_container 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: eventSourceMap.eventbase_blobtrigger_container
  parent: blobSvc
  properties: {
    publicAccess: 'None'
  }
}

resource standard_blobtrigger_container 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: eventSourceMap.standard_blobtrigger_container
  parent: blobSvc
  properties: {
    publicAccess: 'None'
  }
}

resource queuetrigger_container 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: eventSourceMap.queuetrigger_container
  parent: blobSvc
  properties: {
    publicAccess: 'None'
  }
}

resource queueSvc 'Microsoft.Storage/storageAccounts/queueServices@2022-09-01' existing = {
  name: 'default'
  parent: dataStr
}

resource blob_created_queue 'Microsoft.Storage/storageAccounts/queueServices/queues@2022-09-01' = {
  parent: queueSvc
  name: eventSourceMap.blob_created_queue
}

/// deploy application ///

resource funcApp 'Microsoft.Web/sites@2022-03-01' existing = {
  name: funcAppName
}

var addtionalSettings = {
  Project: 'src'
  SCM_COMMAND_IDLE_TIMEOUT: '180'
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

  dependsOn:[
    extractedContainer 
    eventbase_blobtrigger_container 
    standard_blobtrigger_container
    queuetrigger_container
    blob_created_queue
  ]
}

resource source 'Microsoft.Web/sites/sourcecontrols@2022-03-01' = {
  parent: funcApp
  name: 'web'
  properties: {
    repoUrl: funcSrcRepoUrl
    branch: 'main'
    isManualIntegration: true
  }

  dependsOn: [appsettings]
}

/// event grid ///

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

resource subsc1 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2022-06-15' = {
  parent: topic
  name: 'ZipUploaded'
  properties: {
    eventDeliverySchema: 'EventGridSchema'
    filter: {
      subjectBeginsWith: '/blobServices/default/containers/${eventSourceMap.eventbase_blobtrigger_container}/'
      subjectEndsWith: '.zip'
      includedEventTypes:[
        'Microsoft.Storage.BlobCreated'
      ]
    }
    destination: {
      endpointType: 'WebHook'
      properties: {
         endpointUrl: 'https://${funcApp.properties.hostNames[0]}/runtime/webhooks/blobs?functionName=${eventbase_blobtrigger_function}&code=${listkeys('${funcApp.id}/host/default', '2022-03-01').systemKeys.blobs_extension}'
      }
    }
  }
  dependsOn: [
    source
  ]
}

resource queueSenderRoleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: queueSenderRoleid
}

resource queueSenderAssign 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: dataStr
  name: guid(dataStr.id, topic.id, queueSenderRoleid)
  properties:{
    roleDefinitionId: queueSenderRoleDef.id
    principalType: 'ServicePrincipal'
    principalId: topic.identity.principalId
  }
}

resource subsc2 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2022-06-15' = {
  parent: topic
  name: 'EnqueZipUploaded'
  properties: {
    eventDeliverySchema: 'EventGridSchema'
    filter: {
      subjectBeginsWith: '/blobServices/default/containers/${eventSourceMap.queuetrigger_container}/'
      subjectEndsWith: '.zip'
      includedEventTypes:[
        'Microsoft.Storage.BlobCreated'
      ]
    }
    deliveryWithResourceIdentity: {
      identity: {
        type: 'SystemAssigned'
      }
      destination: {
        endpointType: 'StorageQueue'
        properties: {
          resourceId: dataStr.id
          queueName: eventSourceMap.blob_created_queue
        }
      }
    }
  }
  dependsOn:[
    blob_created_queue
    queueSenderAssign
  ]
}
