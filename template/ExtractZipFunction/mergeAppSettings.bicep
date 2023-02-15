param appName string
param settings object

resource appsettings 'Microsoft.Web/sites/config@2022-03-01' = {
  name: '${appName}/appsettings'
  properties: union(list('Microsoft.Web/sites/${appName}/config/appsettings', '2022-03-01').properties, settings)
}
