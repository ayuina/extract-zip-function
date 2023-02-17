param prefix string
param region string
param vnetName string
param pesubnetName string
param funcsubnetName string

var funcStrName = '${replace(prefix, '-', '')}funcstr'
var logAnalyticsName = '${prefix}-laws'
var appInsightsName = '${prefix}-ai'
var funcAppName = '${prefix}-func'
var funcPlanName = '${prefix}-func-plan'

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: vnetName

  resource pesubnet 'subnets' existing = {
    name: pesubnetName
  }
  resource funcsubnet 'subnets' existing = {
    name: funcsubnetName
  }
}

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
    virtualNetworkSubnetId: vnet::funcsubnet.id
    siteConfig:{
      netFrameworkVersion: 'v6.0'
      vnetRouteAllEnabled: true
      functionsRuntimeScaleMonitoringEnabled: true
      publicNetworkAccess: 'Enabled'
      ipSecurityRestrictions: [
        {
          priority: 1000
          name: 'allow-event-grid'
          action: 'Allow'
          tag: 'ServiceTag'
          ipAddress: 'AzureEventGrid'
        }
        {
          priority: 100000
          name: 'deny-all-inbound'
          action: 'Deny'
          ipAddress: 'Any'
        }
      ]
      scmIpSecurityRestrictionsUseMain: true
      scmIpSecurityRestrictions:[
        {
          priority: 100000
          name: 'deny-all-inbound'
          action: 'Deny'
          ipAddress: 'Any'
        }
      ]
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
