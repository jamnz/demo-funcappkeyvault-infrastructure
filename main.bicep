param appName string
param location string = resourceGroup().location

param appNamePrefix string = uniqueString(resourceGroup().id)

var functionAppName = '${appNamePrefix}-functionapp'
var appServiceName = '${appNamePrefix}-appservice'
var appInsightsName = '${appNamePrefix}-appinsights'
var keyVaultName = '${appNamePrefix}-keyvault'

var storageAccountName = format('{0}sta', replace(appNamePrefix,'-',''))

var appTags = {
  AppID : appName
}


// // storage accounts must be between 3 and 24 characters in length and use numbers and lower-case letters only
// var storageAccountName = '${substring(appName,0,10)}${uniqueString(resourceGroup().id)}' 
// var hostingPlanName = '${appName}${uniqueString(resourceGroup().id)}'
// var appInsightsName = '${appName}${uniqueString(resourceGroup().id)}'
// var keyVaultName = 'kv${uniqueString(resourceGroup().id)}'
// var functionAppName = appName

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS' 
  }
  tags:appTags
}

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: { 
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: {
    // circular dependency means we can't reference functionApp directly  /subscriptions/<subscriptionId>/resourceGroups/<rg-name>/providers/Microsoft.Web/sites/<appName>"
     'hidden-link:/subscriptions/${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/sites/${functionAppName}': 'Resource'
     AppID : appName
  }
}

// App Service
resource appService 'Microsoft.Web/serverfarms@2020-10-01' = {
  name: appServiceName
  kind: 'functionapp'
  location: location
  
  sku: {
    name: 'Y1' 
    tier: 'Dynamic'
  }
  tags:appTags
}

resource functionApp 'Microsoft.Web/sites@2020-06-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity:{
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: appService.id
    clientAffinityEnabled: true
    
    siteConfig: {
      appSettings: [
        {
          'name': 'APPINSIGHTS_INSTRUMENTATIONKEY'
          'value': appInsights.properties.InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          'name': 'FUNCTIONS_EXTENSION_VERSION'
          'value': '~4'
        }
        {
          'name': 'FUNCTIONS_WORKER_RUNTIME'
          'value': 'dotnet'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          name:'secretPasswordFromKV'
          value:'@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.azure.net/secrets/secretPassword)'
        }
        // WEBSITE_CONTENTSHARE will also be auto-generated - https://docs.microsoft.com/en-us/azure/azure-functions/functions-app-settings#website_contentshare
        // WEBSITE_RUN_FROM_PACKAGE will be set to 1 by func azure functionapp publish
      ]
    }
  }
  tags:appTags
  // dependsOn: [
  //   appInsights
  //   hostingPlan
  //   storageAccount
  // ]
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: resourceGroup().location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    enableRbacAuthorization: true
    tenantId: subscription().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
  tags:appTags
  // dependsOn: [
  //   functionApp
  //   hostingPlan
  //   storageAccount
  // ]
}

@description('A new GUID used to identify the role assignment')
param roleNameGuid string = newGuid()

resource roleAssignStorage 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: roleNameGuid
  properties: {
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6'
    principalId: functionApp.identity.principalId
  }
  
  scope: keyVault
  // dependsOn:[
  //   keyVaultModule
  //   functionApp
  // ]
}

resource kvSecretModule 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = {
  name: 'secretPassword'  
  parent: keyVault
  properties: {    
    contentType: 'string'
    value: 'some very secret value stored in key vault'
  }
  // dependsOn:[
  //   keyVaultModule
  // ]
}
