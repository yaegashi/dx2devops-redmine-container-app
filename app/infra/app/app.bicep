param containerAppsEnvironmentName string
param containerAppName string
param location string = resourceGroup().location
param tags object = {}
param logAnalyticsWorkspaceName string
param storageAccountName string
param containerRegistryLoginServer string
param appImage string
param kvDatabase string
param kvSecretKeyBase string
param kvMsClientSecret string
param msTenantId string
param msClientId string
param userAssignedIdentityName string
param tz string

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: userAssignedIdentityName
}

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName
  resource blobService 'blobServices' = {
    name: 'default'
    resource data 'containers' = {
      name: 'token-store'
    }
  }
  resource fileService 'fileServices' = {
    name: 'default'
    resource data 'shares' = {
      name: 'data'
    }
  }
}

// See https://learn.microsoft.com/en-us/rest/api/storagerp/storage-accounts/list-service-sas
var sas = storage.listServiceSAS('2022-05-01', {
    canonicalizedResource: '/blob/${storage.name}/token-store'
    signedProtocol: 'https'
    signedResource: 'c'
    signedPermission: 'rwdl'
    signedExpiry: '3000-01-01T00:00:00Z'
  }).serviceSasToken
var sasUrl = 'https://${storage.name}.blob.${environment().suffixes.storage}/token-store?${sas}'

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-08-01-preview' = {
  name: containerAppsEnvironmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
  resource data 'storages' = {
    name: 'data'
    properties: {
      azureFile: {
        accessMode: 'ReadWrite'
        accountName: storage.name
        accountKey: storage.listKeys().keys[0].value
        shareName: storage::fileService::data.name
      }
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2023-08-01-preview' = {
  name: containerAppName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
      }
      registries: [
        {
          server: containerRegistryLoginServer
          identity: userAssignedIdentity.id
        }
      ]
      secrets: [
        {
          name: 'database-url'
          keyVaultUrl: kvDatabase
          identity: userAssignedIdentity.id
        }
        {
          name: 'secret-key-base'
          keyVaultUrl: kvSecretKeyBase
          identity: userAssignedIdentity.id
        }
        {
          name: 'microsoft-provider-authentication-secret'
          keyVaultUrl: kvMsClientSecret
          identity: userAssignedIdentity.id
        }
        {
          name: 'token-store-url'
          value: sasUrl
        }
      ]
    }
    template: {
      volumes: [
        {
          name: 'data'
          storageName: containerAppsEnvironment::data.name
          storageType: 'AzureFile'
        }
      ]
      containers: [
        {
          name: 'redmine'
          image: appImage
          args: [ 'rails' ]
          env: [
            { name: 'TZ', value: tz }
            { name: 'RAILS_ENV', value: 'production' }
            { name: 'DATABASE_URL', secretRef: 'database-url' }
            { name: 'SECRET_KEY_BASE', secretRef: 'secret-key-base' }
          ]
          probes: [
            {
              type: 'Startup'
              httpGet: {
                path: '/'
                port: 8080
                scheme: 'HTTP'
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              timeoutSeconds: 1
              successThreshold: 1
              failureThreshold: 30
            }
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          volumeMounts: [
            {
              volumeName: 'data'
              subPath: 'wwwroot'
              mountPath: '/home/site/wwwroot'
            }
          ]
        }
        {
          name: 'sidekiq'
          image: appImage
          args: [ 'sidekiq' ]
          env: [
            { name: 'TZ', value: tz }
            { name: 'RAILS_ENV', value: 'production' }
            { name: 'DATABASE_URL', secretRef: 'database-url' }
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          volumeMounts: [
            {
              volumeName: 'data'
              subPath: 'wwwroot'
              mountPath: '/home/site/wwwroot'
            }
          ]
        }
        {
          name: 'redis'
          image: 'redis'
          args: [ 'redis-server', '--save', '60', '1', '--loglevel', 'warning' ]
          env: [
            { name: 'TZ', value: tz }
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          volumeMounts: [
            {
              volumeName: 'data'
              subPath: 'redis'
              mountPath: '/data'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }

  resource authConfigs 'authConfigs' = if (!empty(msTenantId) && !empty(msClientId)) {
    name: 'current'
    properties: {
      identityProviders: {
        azureActiveDirectory: {
          registration: {
            clientId: msClientId
            clientSecretSettingName: 'microsoft-provider-authentication-secret'
            openIdIssuer: 'https://sts.windows.net/${msTenantId}/v2.0'
          }
          validation: {
            allowedAudiences: [
              'api://${msClientId}'
            ]
          }
          login: {
            loginParameters: [ 'scope=openid profile email offline_access' ]
          }
        }
      }
      platform: {
        enabled: true
      }
      login: {
        tokenStore: {
          enabled: true
          azureBlobStorage: {
            sasUrlSettingName: 'token-store-url'
          }
        }
      }
    }
  }
}

output defaultDomain string = containerAppsEnvironment.properties.defaultDomain
output envId string = containerAppsEnvironment.id
output envName string = containerAppsEnvironment.name
output appId string = containerApp.id
output appName string = containerApp.name
