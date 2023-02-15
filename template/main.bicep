param prefix string = 'ayuina0215b'
param region string = 'westus3'

var funcStrName = '${prefix}funcstr'
var logAnalyticsName = '${prefix}-laws'
var appInsightsName = '${prefix}-ai'
var funcAppName = '${prefix}-func'
var funcPlanName = '${prefix}-func-plan'


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

module appplication 'func.bicep' = {
  name: 'func'
  params: {
    prefix: prefix
    region: region
    funcAppName: funcAppName
  }

  dependsOn: [
    platform
  ]
}
