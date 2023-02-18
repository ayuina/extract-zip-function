param region string
param funcAppName string
param dataStrName string
param eventbaseBlobTriggerContainerName string
param enqueueTriggerCotainerName string
param blobCreatedQueueName string

var dataStrTopicName = '${dataStrName}-topic'
var eventbaseBlobtriggerFunctionName = 'ExtractArchive'
var queueSenderRoleid = 'c6a89b2d-59bc-44d0-9896-0f6e12d7b80a'

resource funcApp 'Microsoft.Web/sites@2022-03-01' existing = {
  name: funcAppName
}

resource queueSenderRoleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: queueSenderRoleid
}

resource dataStr 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: dataStrName

  resource blobSvc 'blobServices' existing = {
    name: 'default'
  }
  resource queueSvc 'queueServices' existing = {
    name: 'default'
  }  
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


resource queueSenderAssign 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: dataStr
  name: guid(dataStr.id, topic.id, queueSenderRoleid)
  properties:{
    roleDefinitionId: queueSenderRoleDef.id
    principalType: 'ServicePrincipal'
    principalId: topic.identity.principalId
  }
}


resource subsc1 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2022-06-15' = {
  parent: topic
  name: 'ZipUploaded'
  properties: {
    eventDeliverySchema: 'EventGridSchema'
    filter: {
      subjectBeginsWith: '/blobServices/default/containers/${eventbaseBlobTriggerContainerName}/'
      subjectEndsWith: '.zip'
      includedEventTypes:[
        'Microsoft.Storage.BlobCreated'
      ]
    }
    destination: {
      endpointType: 'WebHook'
      properties: {
         endpointUrl: 'https://${funcApp.properties.hostNames[0]}/runtime/webhooks/blobs?functionName=${eventbaseBlobtriggerFunctionName}&code=${listkeys('${funcApp.id}/host/default', '2022-03-01').systemKeys.blobs_extension}'
      }
    }
  }
}

resource subsc2 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2022-06-15' = {
  parent: topic
  name: 'EnqueZipUploaded'
  properties: {
    eventDeliverySchema: 'EventGridSchema'
    filter: {
      subjectBeginsWith: '/blobServices/default/containers/${enqueueTriggerCotainerName}/'
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
          queueName: blobCreatedQueueName
        }
      }
    }
  }
}

output eventGridEndpoint string = 'https://${funcApp.properties.hostNames[0]}/runtime/webhooks/blobs?functionName=${eventbase_blobtrigger_function}&code=${listkeys('${funcApp.id}/host/default', '2022-03-01').systemKeys.blobs_extension}'
