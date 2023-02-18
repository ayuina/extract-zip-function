param appName string
param settings1 object
param settings2 object

resource appsettings 'Microsoft.Web/sites/config@2022-03-01' = {
  name: '${appName}/appsettings'
  properties: union(settings1, settings2)
}

//https://github.com/Azure/azure-cli/issues/11718

// module mergeSettings 'mergeAppSettings.bicep' = {
//   name: 'mergeSettings'
//   params: {
//     appName: funcAppName
//     settings1: list('Microsoft.Web/sites/${funcAppName}/config/appsettings', '2022-03-01').properties
//     settings2: union(additionalSettings, eventSourceMap)
//   }
// }
