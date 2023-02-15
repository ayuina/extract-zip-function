param appName string
param setting1 object
param setting2 object

resource appsettings 'Microsoft.Web/sites/config@2022-03-01' = {
  name: '${appName}/appsettings'
  properties: union(setting1, setting2)
}
