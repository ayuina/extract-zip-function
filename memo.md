
クイックスタートに従い .net の vrersion を固定
https://learn.microsoft.com/ja-jp/azure/azure-functions/create-first-function-cli-csharp?tabs=azure-cli%2Cin-process


```powershell
> winget install --id Microsoft.DotNet.SDK.6 --version 6.0.405

> dotnet --list-sdks

6.0.308 [C:\Program Files\dotnet\sdk]
6.0.405 [C:\Program Files\dotnet\sdk]
7.0.102 [C:\Program Files\dotnet\sdk]

> dotnet new globaljson --sdk-version 6.0.405

テンプレート "global.json ファイル" が正常に作成されました。

> cat global.json

{
  "sdk": {
    "version": "6.0.405"
  }
}
```

# function core tools

```powershell
# install 
> winget install --id Microsoft.AzureFunctionsCoreTools --version 4.0.4915

> func --version
4.0.4915

```

# azure cli

```powershell

> winget install --id Microsoft.AzureCLI --version 2.44.1

> az --version
azure-cli                         2.44.1

> az login --tenant fdpo.onmicrosoft.com

> az account set -s 525c042d-41ad-41f2-bed6-d5d67a56fef7

```

# set up app code

```powershell

> func init --worker-runtime dotnet 

# https://learn.microsoft.com/ja-jp/azure/azure-functions/functions-event-grid-blob-trigger?pivots=programming-language-csharp

> func new --language C# --template BlobTrigger --n ExtractArchive3

# https://www.nuget.org/packages/Microsoft.Azure.WebJobs.Extensions.Storage


```

# publish func app 

```powershell
$funcapp = 'ainaba0130'
$rg = 'demo0130-rg'
$funcname = 'ExtractArchive'
$stracc = "demo0130rgbfa1"

func azure functionapp publish $funcapp

$funckey = az functionapp keys list -g $rg -n $funcapp --query "systemKeys.blobs_extension" -o tsv
$url = "https://${funcapp}.azurewebsites.net/runtime/webhooks/blobs?functionName=${funcname}&code=${funckey}"
echo $url


func azure functionapp logstream ainaba0130


```

# event subscription 

upgrade v2

# performance

https://learn.microsoft.com/ja-jp/azure/azure-functions/performance-reliability
async

Dynamic bind
https://learn.microsoft.com/ja-jp/azure/azure-functions/functions-dotnet-class-library?tabs=v2%2Ccmd

BlobOutput
https://learn.microsoft.com/ja-jp/azure/azure-functions/functions-bindings-storage-blob-output?tabs=in-process%2Cextensionv5&pivots=programming-language-csharp

# test

$strkey = az storage account keys list -g $rg -n $stracc --query "[0].value" -o tsv
$strconstr = az storage account show-connection-string -g $rg -n $stracc --query "connectionString" -o tsv

$upcon = 'archive-upload'

az storage blob upload --connection-string $strconstr  --container $upcon --file .\sysinternals.zip   

az storage blob copy start --connection-string $strconstr --source-container $upcon --source-blob openjdk.zip --destination-container $upcon --destination-blob hoge.zip

az storage blob upload --connection-string $strconstr  --container $upcon --file .\wafcost.zip   
az storage blob copy start --connection-string $strconstr --source-container $upcon --source-blob wafcost.zip --destination-container $upcon --destination-blob hoge.zip

for($x = 0; $x -lt 100; $x++){
  az storage blob copy start --connection-string $strconstr --source-container $upcon --source-blob wafcost.zip --destination-container $upcon --destination-blob "hoge_${x}.zip"  --requires-sync false
}

