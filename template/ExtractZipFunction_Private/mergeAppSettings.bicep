param appName string
param settings1 object
param settings2 object

resource appsettings 'Microsoft.Web/sites/config@2022-03-01' = {
  name: '${appName}/appsettings'
  properties: union(settings1, settings2)
}
