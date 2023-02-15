param prefix string
param region string

var funcStrName = '${prefix}funcstr'
var logAnalyticsName = '${prefix}-laws'
var appInsightsName = '${prefix}-ai'
var funcAppName = '${prefix}-func'
var funcPlanName = '${prefix}-func-plan'
var funcSrcRepoUrl = 'https://github.com/ayuina/extract-zip-function.git'

resource funcStr 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: funcStrName
  location: region
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
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
    siteConfig:{
      appSettings:[
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appinsights.properties.InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${funcStrName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${funcStr.listKeys().keys[0].value}'
        }
        {
          name: 'AzureWebJobsDashboard'
          value: 'DefaultEndpointsProtocol=https;AccountName=${funcStrName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${funcStr.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${funcStrName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${funcStr.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(funcAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'Project'
          value: 'src'
        }
        {
          name: 'SCM_COMMAND_IDLE_TIMEOUT'
          value: '180'
        }
      ]
    }
  }
}

resource source 'Microsoft.Web/sites/sourcecontrols@2022-03-01' = {
  parent: funcApp
  name: 'web'
  properties: {
    repoUrl: funcSrcRepoUrl
    branch: 'main'
    isManualIntegration: true
  }
}



output funcAppName string = funcAppName
