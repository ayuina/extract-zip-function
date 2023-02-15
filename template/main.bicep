param prefix string = 'ayuina0215b'
param region string = 'westus3'

var funcStrName = '${prefix}funcstr'
var logAnalyticsName = '${prefix}-laws'
var appInsightsName = '${prefix}-ai'
var funcAppName = '${prefix}-func'
var funcPlanName = '${prefix}-func-plan'

var dataStrName = '${prefix}datastr'

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

module appplication 'application.bicep' = {
  name: 'application'
  params: {
    region: region
    funcAppName: funcAppName
    dataStrName: dataStrName
  }

  dependsOn: [
    platform
  ]
}
