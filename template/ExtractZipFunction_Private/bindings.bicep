param prefix string
param region string
param vnetName string
param pesubnetName string
param funcAppName string

var dataStrName = '${replace(prefix, '-', '')}datastr'
var dataStrBlobPeName = '${dataStrName}-blob-pe'
var dataStrQueuePeName = '${dataStrName}-queue-pe'
var dataStrTopicName = '${dataStrName}-topic'

var eventSourceMap = {
  eventbase_blobtrigger_container: 'archive-upload-for-eventgrid'
  standard_blobtrigger_container:'archive-upload-for-polling'
  queuetrigger_container: 'archive-upload-for-queue'
  blob_created_queue:'archive-upload-queue'
  extracted_container: 'archive-extracted'
}

var eventbase_blobtrigger_function = 'ExtractArchive'
var queueSenderRoleid = 'c6a89b2d-59bc-44d0-9896-0f6e12d7b80a'
var funcSrcRepoUrl = 'https://github.com/ayuina/extract-zip-function.git'

///

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: vnetName

  resource pesubnet 'subnets' existing = {
    name: pesubnetName
  }
}

resource blobZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
}

resource queueZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.queue.${environment().suffixes.storage}'
}


resource funcApp 'Microsoft.Web/sites@2022-03-01' existing = {
  name: funcAppName
}

resource queueSenderRoleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: queueSenderRoleid
}

///

resource dataStr 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: dataStrName
  location: region
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }

  resource blobSvc 'blobServices' existing = {
    name: 'default'

    resource extractedContainer 'containers' = {
      name: eventSourceMap.extracted_container
      properties: {
        publicAccess: 'None'
      }
    }

    resource eventbase_blobtrigger_container 'containers' = {
      name: eventSourceMap.eventbase_blobtrigger_container
      properties: {
        publicAccess: 'None'
      }
    }

    resource standard_blobtrigger_container 'containers' = {
      name: eventSourceMap.standard_blobtrigger_container
      properties: {
        publicAccess: 'None'
      }
    }

    resource queuetrigger_container 'containers' = {
      name: eventSourceMap.queuetrigger_container
      properties: {
        publicAccess: 'None'
      }
    }

  }

  resource queueSvc 'queueServices' existing = {
    name: 'default'

    resource blob_created_queue 'queues' = {
      name: eventSourceMap.blob_created_queue
    }
  }
    
}


module blobPe './privateEndpoint.bicep' = {
  name: dataStrBlobPeName
  params:{
    region: region
    svcname: dataStr.name
    svctype: dataStr.type
    zonename: blobZone.name
    groupId: 'blob'
    vnetName: vnetName
    pesubnetName: pesubnetName
  }
}

module queuePe './privateEndpoint.bicep' = {
  name: dataStrQueuePeName
  params:{
    region: region
    svcname: dataStr.name
    svctype: dataStr.type
    zonename: queueZone.name
    groupId: 'queue'
    vnetName: vnetName
    pesubnetName: pesubnetName
  }
}


var additionalSettings = {
  AzureWebJobsDataStorage: 'DefaultEndpointsProtocol=https;AccountName=${dataStrName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${dataStr.listKeys().keys[0].value}'
}

//https://github.com/Azure/azure-cli/issues/11718
module mergeSettings 'mergeAppSettings.bicep' = {
  name: 'mergeSettings'
  params: {
    appName: funcAppName
    settings1: list('Microsoft.Web/sites/${funcAppName}/config/appsettings', '2022-03-01').properties
    settings2: union(additionalSettings, eventSourceMap)
  }
}

resource appSource 'Microsoft.Web/sites/sourcecontrols@2022-03-01' = {
  parent: funcApp
  name: 'web'
  properties: {
    repoUrl: funcSrcRepoUrl
    branch: 'main'
    isManualIntegration: true
  }
  dependsOn:[
    mergeSettings
  ]
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

  dependsOn:[appSource]
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
  dependsOn:[
    dataStr::blobSvc::eventbase_blobtrigger_container
  ]
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
    dataStr::blobSvc::queuetrigger_container
    dataStr::queueSvc::blob_created_queue
    queueSenderAssign
  ]
}
