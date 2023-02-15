
resource funcApp 'Microsoft.Web/sites@2022-03-01' existing = {
  name: 'ayuina0215c-func'
}

resource func 'Microsoft.Web/sites/functions@2022-03-01' existing = {
  name: 'ayuina0215c-func/ExtractArchive'
}

// https://stackoverflow.com/questions/69251430/output-newly-created-function-app-key-using-bicep
output blobkey string = listkeys('${funcApp.id}/host/default', '2022-03-01').systemKeys.blobs_extension


output funclevelkey object = func.listkeys()
//output funclevelsec object = func.listsecrets()

