param storageAccountName string
param dbAdminUser string
@secure()
param dbAdminPass string
param location string
param tags object

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName
  resource blobService 'blobServices' = {
    name: 'default'
    resource secrets 'containers' = {
      name: 'secrets'
    }
  }
}

// See https://learn.microsoft.com/en-us/rest/api/storagerp/storage-accounts/list-service-sas
var sas = storage.listServiceSAS('2022-05-01', {
    canonicalizedResource: '/blob/${storage.name}/secrets'
    signedProtocol: 'https'
    signedResource: 'c'
    signedPermission: 'w'
    signedExpiry: '3000-01-01T00:00:00Z'
  }).serviceSasToken

var url = 'https://${storage.name}.blob.${environment().suffixes.storage}/secrets'

var scriptContent = '''
$variables = @(
  'DB_ADMIN_USER'
  'DB_ADMIN_PASS'
)
$headers = @{
  'Content-Type'   = 'application/octet-stream'
  'x-ms-date'      = (Get-Date).ToUniversalTime().ToString('R')
  'x-ms-version'   = '2020-02-10'
  'x-ms-blob-type' = 'BlockBlob'
}
foreach ($var in $variables) {
  $data = [System.Text.Encoding]::UTF8.GetBytes([Environment]::GetEnvironmentVariable($var))
  $response = Invoke-RestMethod -Uri "${env:URL}/${var}?${env:SAS}" -Method Put -Headers $headers -Body $data
  if ($response.StatusCode -ge 400) {
      throw "HTTP request failed with status code $($response.StatusCode)"
  }
}
'''

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'deploymentScript'
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '9.7'
    environmentVariables: [
      { name: 'URL', value: url }
      { name: 'SAS', secureValue: sas }
      { name: 'DB_ADMIN_USER', secureValue: dbAdminUser }
      { name: 'DB_ADMIN_PASS', secureValue: dbAdminPass }
    ]
    scriptContent: scriptContent
    retentionInterval: 'P1D'
  }
}
