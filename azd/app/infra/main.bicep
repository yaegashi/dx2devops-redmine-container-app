targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param principalId string

param userAssignedIdentityName string = ''

param resourceGroupName string = ''

param keyVaultName string = ''

param storageAccountName string = ''

param logAnalyticsName string = ''

param applicationInsightsName string = ''

param applicationInsightsDashboardName string = ''

param containerAppName string = ''

param containerAppsEnvironmentName string = ''

param appImage string = ''
param appDbUrlFormat string = ''
@secure()
param appDbPass string
@secure()
param appSecretKeyBase string

param tz string = 'Asia/Tokyo'

param msTenantId string = ''
param msClientId string = ''
@secure()
param msClientSecret string = ''

var abbrs = loadJsonContent('./abbreviations.json')

var tags = {
  'azd-env-name': environmentName
}

#disable-next-line no-unused-vars
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module keyVault './core/security/keyvault.bicep' = {
  name: 'keyVault'
  scope: rg
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    principalId: principalId
  }
}

module keyVaultSecretAppDbPass './core/security/keyvault-secret.bicep' = {
  name: 'keyVaultSecretAppDbPass'
  scope: rg
  params: {
    name: 'appDbPass'
    tags: tags
    keyVaultName: keyVault.outputs.name
    secretValue: appDbPass
  }
}

module keyVaultSecretAppSecretKeyBase './core/security/keyvault-secret.bicep' = {
  name: 'keyVaultSecretAppSecretKeyBase'
  scope: rg
  params: {
    name: 'appSecretKeyBase'
    tags: tags
    keyVaultName: keyVault.outputs.name
    secretValue: appSecretKeyBase
  }
}

module keyVaultSecretMsClientSecret './core/security/keyvault-secret.bicep' = {
  name: 'keyVaultSecretMsClientSecret'
  scope: rg
  params: {
    name: 'msClientSecret'
    tags: tags
    keyVaultName: keyVault.outputs.name
    secretValue: msClientSecret
  }
}

var xTZ = !empty(tz) ? tz : 'Asia/Tokyo'
var xAppImage = !empty(appImage) ? appImage : 'ghcr.io/yaegashi/dx2devops-redmine-containerapp/redmica:v2.4.0-main'
var xContainerAppsEnvironmentName = !empty(containerAppsEnvironmentName) ? containerAppsEnvironmentName : '${abbrs.appManagedEnvironments}${resourceToken}'
var xContainerAppName = !empty(containerAppName) ? containerAppName : '${abbrs.appContainerApps}${resourceToken}'
var appDbName = replace(xContainerAppName, '-', '_')
var appDbUrl = format(appDbUrlFormat, appDbName, appDbPass, appDbName)

module keyVaultSecretDatabaseUrl './core/security/keyvault-secret.bicep' = {
  name: 'keyVaultSecretDatabaseUrl'
  scope: rg
  params: {
    name: 'appDbUrl'
    tags: tags
    keyVaultName: keyVault.outputs.name
    secretValue: appDbUrl
  }
}

module userAssignedIdentity './app/identity.bicep' = {
  name: 'userAssignedIdentity'
  scope: rg
  params: {
    name: !empty(userAssignedIdentityName) ? userAssignedIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}'
    location: location
    tags: tags
  }
}

module KeyVaultAccess './core/security/keyvault-access.bicep' = {
  name: 'KeyVaultAccess'
  scope: rg
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: userAssignedIdentity.outputs.principalId
  }
}

module storageAccount './core/storage/storage-account.bicep' = {
  name: 'storageAccount'
  scope: rg
  params: {
    location: location
    tags: tags
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
  }
}

module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
  }
}

module app './app/app.bicep' = {
  dependsOn: [ KeyVaultAccess ]
  name: 'app'
  scope: rg
  params: {
    location: location
    tags: tags
    containerAppsEnvironmentName: xContainerAppsEnvironmentName
    containerAppName: xContainerAppName
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    storageAccountName: storageAccount.outputs.name
    appImage: xAppImage
    kvDatabase: '${keyVault.outputs.endpoint}secrets/appDbUrl'
    kvSecretKeyBase: '${keyVault.outputs.endpoint}secrets/appSecretKeyBase'
    kvMsClientSecret: '${keyVault.outputs.endpoint}secrets/msClientSecret'
    userAssignedIdentityName: userAssignedIdentity.outputs.name
    msTenantId: msTenantId
    msClientId: msClientId
    tz: xTZ
  }
}

var portalLink = 'https://portal.azure.com/${tenant().tenantId}'

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.endpoint
