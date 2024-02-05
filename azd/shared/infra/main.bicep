targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param principalId string

@allowed([ 'mysql', 'psql' ])
param dbType string = 'mysql'
param dbName string = ''
param dbAdminUser string = 'adminuser'
@secure()
param dbAdminPass string

param msTenantId string = ''
param msClientId string = ''
@secure()
param msClientSecret string = ''

param resourceGroupName string = ''

param keyVaultName string = ''

param containerRegistryName string = ''

param logAnalyticsName string = ''

param applicationInsightsName string = ''

param applicationInsightsDashboardName string = ''

param utcValue string = utcNow()

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

var dbtags = 'mysql' == dbType ? mysql.outputs.tags : psql.outputs.tags

module keyVaultSecretDbAdminPass './core/security/keyvault-secret.bicep' = {
  name: 'keyVaultSecretDbAdminPass'
  scope: rg
  params: {
    name: 'DB-ADMIN-PASS'
    tags: tags
    keyVaultName: keyVault.outputs.name
    secretValue: dbAdminPass
  }
}

module keyVaultSecretMsClientSecret './core/security/keyvault-secret.bicep' = {
  name: 'keyVaultSecretMsClientSecret'
  scope: rg
  params: {
    name: 'MS-CLIENT-SECRET'
    tags: tags
    keyVaultName: keyVault.outputs.name
    secretValue: msClientSecret
  }
}

module mysql './app/mysql.bicep' = if (dbType == 'mysql') {
  scope: rg
  name: 'mysql'
  params: {
    location: location
    dbName: !empty(dbName) ? dbName : '${abbrs.dBforMySQLServers}${resourceToken}'
    dbAdminUser: dbAdminUser
    dbAdminPass: dbAdminPass
  }
}

module psql './app/psql.bicep' = if (dbType == 'psql') {
  scope: rg
  name: 'psql'
  params: {
    location: location
    dbName: !empty(dbName) ? dbName : '${abbrs.dBforPostgreSQLServers}${resourceToken}'
    dbAdminUser: dbAdminUser
    dbAdminPass: dbAdminPass
  }
}

module containerRegistry './core/host/container-registry.bicep' = {
  name: 'containerRegistry'
  scope: rg
  params: {
    location: location
    tags: tags
    name: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    workspaceId: monitoring.outputs.logAnalyticsWorkspaceId
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

module rgtags './app/tags.bicep' = {
  name: '${rg.name}-${utcValue}'
  params: {
    name: rg.name
    location: rg.location
    tags: union(rg.tags, dbtags, {
      MS_TENANT_ID: msTenantId
      MS_CLIENT_ID: msClientId
      KEY_VAULT_NAME: keyVault.outputs.name
      CONTAINER_REGISTRY_NAME: containerRegistry.outputs.name
      CONTAINER_REGISTRY_LOGIN_SERVER: containerRegistry.outputs.loginServer
      CONTAINER_REGISTRY_IMAGE: '${containerRegistry.outputs.loginServer}/app'
    })
  }
}

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output AZURE_RESOURCE_GROUP_NAME string = rg.name
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.endpoint
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.outputs.name
output AZURE_CONTAINER_REGISTRY_LOGIN_SERVER string = containerRegistry.outputs.loginServer
output AZURE_CONTAINER_REGISTRY_IMAGE string = '${containerRegistry.outputs.loginServer}/app'
