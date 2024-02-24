param containerAppsEnvironmentName string
param containerAppName string
param location string
param tags object = {}
param containerRegistryLoginServer string
param appImage string
param kvDatabase string
param userAssignedIdentityName string
param tz string

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: userAssignedIdentityName
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-08-01-preview' existing = {
  name: containerAppsEnvironmentName
  resource data 'storages' existing = {
    name: 'data'
  }
}

resource job 'Microsoft.App/jobs@2023-05-01' = {
  name: '${containerAppName}-job'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    environmentId: containerAppsEnvironment.id
    configuration: {
      replicaTimeout: 300
      triggerType: 'Manual'
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
          name: 'job'
          image: appImage
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
      ]
    }
  }
}

output id string = job.id
output name string = job.name
