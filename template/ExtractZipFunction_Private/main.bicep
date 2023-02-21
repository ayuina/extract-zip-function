param prefix string
param region string
param privateNetworkRange24 string
param runFromPackageUrl string

module infra './infrastructure.bicep' = {
  name: 'infra'
  params: {
    prefix: prefix
    region: region
    vnetaddressPrefix24: privateNetworkRange24
  }
}

var eventSourceMap = {
  eventbase_blobtrigger_container: 'archive-upload-for-eventgrid'
  standard_blobtrigger_container:'archive-upload-for-polling'
  queuetrigger_container: 'archive-upload-for-queue'
  blob_created_queue:'archive-upload-queue'
  extracted_container: 'archive-extracted'
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
    eventSourceMap: eventSourceMap
  }
}

module bindings './bindings.bicep' = {
  name: 'bindings'
  params: {
    region: region
    funcAppName: platform.outputs.funcAppName
    dataStrName: platform.outputs.dataStrName
    dataStrTopicName: infra.outputs.dataStrTopicName
    eventbaseBlobTriggerContainerName: eventSourceMap.eventbase_blobtrigger_container
    enqueueTriggerCotainerName: eventSourceMap.queuetrigger_container
    blobCreatedQueueName: eventSourceMap.blob_created_queue
  }
}
