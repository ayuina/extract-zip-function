# prerequisite

- [WSL](https://learn.microsoft.com/ja-jp/windows/wsl/install)
- [.NET 6.0 SDK](https://dotnet.microsoft.com/en-us/download/dotnet/6.0)
- [Azure CLI](https://learn.microsoft.com/ja-jp/cli/azure/install-azure-cli-linux?pivots=apt)
- [Azure Functions Core Tools](https://github.com/Azure/azure-functions-core-tools)

# parameters

```bash
region='westus3'
rg='private-blob-trigger-rg'

prefix='ayuina0206'
funcstr="${prefix}funcstr"

funcplan="${prefix}-func-plan"
funcapp="${prefix}-func"
funcname='ExtractArchive'

datastr="${prefix}datastr"
uploadContainer='archive-upload'
extractContainer='archive-extracted'
topic="${datastr}-topic"
eventsubsc='ZipUploaded'
datastrAppSetting="AzureWebJobsDataStorage"

laws="${prefix}-laws"
appins="${prefix}-ai"

vnet="${prefix}-vnet"
funcsubnet="FunctionsSubnet"
pesubnet="PrivateEndpointSubnet"
vmsubnet="VMSubnet"

vm="${prefix}-vm"
vmnsg="${vm}-nsg"
vmpip="${vm}-pip"
vmnic="${vm}-nic"
vmimg='MicrosoftVisualStudio:visualstudio2022:vs-2022-ent-latest-ws2022:2023.01.13'
username="${prefix}"
```

# create platform
```bash
az login --tenant 'MngEnvMCAP784488.onmicrosoft.com'

# resource group
az group create --name $rg --location $region

# vnet
az network vnet create --location $region --resource-group $rg --name $vnet  --address-prefixes '192.168.206.0/24' \
    --subnet-name $funcsubnet --subnet-prefix '192.168.206.0/26'
az network vnet subnet create --resource-group $rg --vnet-name $vnet \
   --name $pesubnet --address-prefixes '192.168.206.64/26'
az network vnet subnet create --resource-group $rg --vnet-name $vnet \
   --name $vmsubnet --address-prefixes '192.168.206.128/26'

# data storage
az storage account create --location $region --resource-group $rg --name $datastr --sku 'Standard_LRS'
dataconstr=`az storage account show-connection-string -g $rg -n $datastr --query "connectionString" -o tsv`
az storage container create --connection-string $dataconstr --name $uploadContainer
az storage container create --connection-string $dataconstr --name $extractContainer

# private endpoint of data storage
datastrid=`az storage account show --resource-group $rg --name $datastr --query "id" -o tsv`
blobpe="${datastr}-blob-pe"
az network private-endpoint create --resource-group $rg --name $blobpe --connection-name "blob-pe" \
    --vnet-name $vnet --subnet $pesubnet --private-connection-resource-id $datastrid --group-id blob
blobZone=`az network private-link-resource list -g $rg -n $datastr --type Microsoft.Storage/storageAccounts --query "[?name=='blob'] | [0].properties.requiredZoneNames" -o tsv`
az network private-dns zone create --resource-group $rg --name $blobZone
az network private-dns link vnet create --resource-group $rg --zone-name $blobZone --name "blob-link" --virtual-network $vnet --registration-enabled false
az network private-endpoint dns-zone-group create --resource-group $rg --private-dns-zone $blobZone --endpoint-name $blobpe --name "blob-pe-zone-group"  --zone-name 'config1'

# deny access from public
az storage account update --name $datastr --resource-group $rg --public-network-access Disabled

# azure functions
az storage account create --location $region --resource-group $rg --name $funcstr --sku 'Standard_LRS'
az functionapp plan create --location $region --resource-group $rg --name $funcplan  --sku 'EP1'
az functionapp create --resource-group $rg  --name $funcapp --plan $funcplan \
    --storage-account $funcstr --functions-version 4
az functionapp config appsettings set --resource-group $rg --name $funcapp \
    --settings "${datastrAppSetting}=${dataconstr}"

az webapp vnet-integration add --resource-group $rg --name $funcapp --vnet $vnet --subnet $funcsubnet
az functionapp config appsettings set --resource-group $rg --name $funcapp \
    --settings "vnetrouteallenabled=1"

### private endpoint
### allow inbound from event grid
### enable vnet trigger
### binding path to app settings

### eventgrid private mondai
https://learn.microsoft.com/ja-jp/azure/event-grid/managed-service-identity#private-endpoints

# monitoring
az monitor log-analytics workspace create --location $region --resource-group $rg --workspace-name $laws --sku PerGB2018
lawsid=`az monitor log-analytics workspace show --resource-group $rg --workspace-name $laws --query "id" -o tsv`
az monitor app-insights component create --location $region --resource-group $rg --app $appins --workspace $lawsid
az monitor app-insights component connect-function --resource-group $rg --app $appins --function $funcapp

# work vm
az network nsg create --location $region --resource-group $rg --name $vmnsg
clientip=$(curl ifconfig.io/ip)
az network nsg rule create --resource-group $rg --nsg-name $vmnsg \
    --name AllowRdp --priority 1000 --direction Inbound --protocol Tcp \
    --source-address-prefixes $clientip --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 3389
az network public-ip create  --location $region --resource-group $rg --name $vmpip \
    --allocation-method Dynamic --dns-name $vm
vmsubnetid=$(az network vnet subnet show -g $rg --vnet-name $vnet -n $vmsubnet --query id -o tsv)
az network nic create --location $region --resource-group $rg --name $vmnic \
    --subnet $vmsubnetid --network-security-group $vmnsg --public-ip-address $vmpip
az vm create --location $region --resource-group $rg --name $vm  \
    --size Standard_D2s_v4 --nics $vmnic \
    --image $vmimg --authentication-type password --admin-username $username 

```

# publish app

```bash
func azure functionapp publish $funcapp

funckey=`az functionapp keys list -g $rg -n $funcapp --query "systemKeys.blobs_extension" -o tsv`
url="https://${funcapp}.azurewebsites.net/runtime/webhooks/blobs?functionName=${funcname}&code=${funckey}"
echo $url

strid=`az storage account show --resource-group $rg --name $datastr --query 'id' --output tsv`
az eventgrid system-topic create --resource-group $rg --location $region --name $topic \
     --topic-type 'Microsoft.Storage.StorageAccounts' --source $strid

az eventgrid system-topic event-subscription create \
    --resource-group $rg --system-topic-name $topic --name $eventsubsc \
    --included-event-types 'Microsoft.Storage.BlobCreated' \
    --subject-begins-with "/blobServices/default/containers/${uploadContainer}" --subject-ends-with '.zip' \
    --endpoint-type 'webhook' --event-delivery-schema 'eventgridschema' --endpoint $url

```

# test extract

```bash

az storage blob upload --connection-string $dataconstr  --container $uploadContainer \
    --file ./sysinternals.zip  --overwrite

```