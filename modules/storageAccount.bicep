param name string
param location string = resourceGroup().location
param sku string
param kind string = 'StorageV2'

resource stg 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: name
  location: location
  kind: kind
  sku:{
    name:sku
  }
}

output storageAccountConnectionString string = 'DefaultEndpointsProtocol=https;AccountName=${name};AccountKey=${listKeys(resourceId(resourceGroup().name, 'Microsoft.Storage/storageAccounts', name), '2019-04-01').keys[0].value};EndpointSuffix=core.windows.net'
