# demo-funcappkeyvault-infrastructure

 Azure Function KeyVault Integration Bicep deploy

 Setup
 Create resource group
Azure CLI

az group create -n dev1-rg-demo-funcappkeyvault -l australiaeast

Generate deployment credentials
Your GitHub action runs under an identity. Use the az ad sp create-for-rbac command to create a service principal for the identity.

Replace the placeholder myApp with the name of your application. Replace {subscription-id} with your subscription ID.


az ad sp create-for-rbac --name demo-funcappkeyvault --role contributor --scopes /subscriptions/{subscription-id} --sdk-auth


Deploy bicep code
az deployment group create -f ./main.bicep -g dev1-rg-funcappkeyvault --parameter "appName=funcappDemo1"