param prefix string
param region string
param vnetName string
param pesubnetName string
param funcsubnetName string
param runFromPackageUrl string
param funcStrName string
param dataStrName string
param eventSourceMap object

var logAnalyticsName = '${prefix}-laws'
var appInsightsName = '${prefix}-ai'

var funcAppName = '${prefix}-func'
var funcPlanName = '${prefix}-func-plan'
var funcFilesName = toLower(funcAppName)


resource funcStr 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: funcStrName
  
  resource fileSvc 'fileServices' existing = {
    name: 'default'

    resource funcFilesShare 'shares' = {
      name: funcFilesName
    }
  }
}

resource dataStr 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: dataStrName

  resource blobSvc 'blobServices' existing = {
    name: 'default'

    resource extractedContainer 'containers' = {
      name: eventSourceMap.extracted_container
    }

    resource eventbaseBlobTriggerContainer 'containers' = {
      name: eventSourceMap.eventbase_blobtrigger_container
    }

    resource standardBlobTriggerContainer 'containers' = {
      name: eventSourceMap.standard_blobtrigger_container
    }
    
    resource enqueueTrigerContainer 'containers' = {
      name: eventSourceMap.queuetrigger_container
    }
  }

  resource queueSvc 'queueServices' existing = {
    name: 'default'

    resource signal 'queues' = {
      name: eventSourceMap.blob_created_queue
    }
  }  
}


resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: vnetName

  resource pesubnet 'subnets' existing = {
    name: pesubnetName
  }
  resource funcsubnet 'subnets' existing = {
    name: funcsubnetName
  }
}


resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: region
  properties:{
    sku:{
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource appinsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: region
  kind: 'web'
  properties:{
    Application_Type: 'web'
    Request_Source: 'IbizaWebAppExtensionCreate'
    WorkspaceResourceId: logAnalytics.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource funcPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: funcPlanName
  location: region
  kind: 'elastic'
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
    family: 'EP'
  }
  properties: {
    maximumElasticWorkerCount: 3
  }
}

resource funcApp 'Microsoft.Web/sites@2022-03-01' = {
  name: funcAppName
  location: region
  kind: 'functionapp'
  properties:{
    serverFarmId: funcPlan.id
    clientAffinityEnabled: false
    virtualNetworkSubnetId: vnet::funcsubnet.id
    siteConfig:{
      netFrameworkVersion: 'v6.0'
      vnetRouteAllEnabled: true
      functionsRuntimeScaleMonitoringEnabled: true
      publicNetworkAccess: 'Enabled'
      ipSecurityRestrictionsDefaultAction: 'Deny'
      ipSecurityRestrictions: [
        {
          priority: 1000
          name: 'allow-event-grid'
          action: 'Allow'
          tag: 'ServiceTag'
          ipAddress: 'AzureEventGrid'
        }
      ]
      scmIpSecurityRestrictionsUseMain: true
      scmIpSecurityRestrictionsDefaultAction: 'Deny'
      scmIpSecurityRestrictions: [
      ]
      appSettings:[
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appinsights.properties.InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${funcStrName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${funcStr.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${funcStrName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${funcStr.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: funcFilesName
        }
        {
          name: 'WEBSITE_CONTENTOVERVNET'
          value: '1'
        }
        {
          name: 'WEBSITE_DNS_SERVER'
          value: '168.63.129.16'
        }
        {
          name: 'AzureWebJobsDataStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${dataStrName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${dataStr.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: runFromPackageUrl
        }
        // {
        //   name: 'Project'
        //   value: 'src'
        // }
        // {
        //   name: 'SCM_COMMAND_IDLE_TIMEOUT'
        //   value: '180'
        // }
      ]
    }
  }
}

// resource source 'Microsoft.Web/sites/sourcecontrols@2022-03-01' = {
//   parent: funcApp
//   name: 'web'
//   properties: {
//     repoUrl: funcSrcRepoUrl
//     branch: 'main'
//     isManualIntegration: true
//   }
// }

module mergeSettings 'mergeAppSettings.bicep' = {
  name: 'mergeSettings'
  params: {
    appName: funcApp.name
    settings1: list('Microsoft.Web/sites/${funcApp.name}/config/appsettings', '2022-03-01').properties
    settings2: eventSourceMap
  }
}


resource appsvcZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.azurewebsites.net'
}

module funcPe './privateEndpoint.bicep' = {
  name: '${funcAppName}-pe'
  params:{
    region: region
    svcname: funcApp.name
    svctype: funcApp.type
    zonename: appsvcZone.name
    groupId: 'sites'
    vnetName: vnetName
    pesubnetName: pesubnetName
  }
}


output funcAppName string = funcAppName
output vnetName string = vnetName
output pesubnetName string = pesubnetName
output dataStrName string = dataStrName
output eventSourceMap object = eventSourceMap
