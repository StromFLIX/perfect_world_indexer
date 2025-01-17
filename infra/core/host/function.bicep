param location string = resourceGroup().location
param tags object = {}
param sourceStorageAccountName string
param FunctionPlanName string
param functionAppName string
param identityId string
param identityClientId string
param principalID string
param functionContainerName string
param integrationSubnetId string
param documentIntelligenceName string
param openAIName string

resource sourceStorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: sourceStorageAccountName
}

resource documentIntelligence 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = {
  name: documentIntelligenceName
}

resource openAI 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = {
  name: openAIName
}


resource flexFunctionPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: FunctionPlanName
  location: location
  tags: tags
  kind: 'functionapp'
  sku: {
    tier: 'FlexConsumption'
    name: 'FC1'
  }
  properties: {
    reserved: true
  }
}

resource flexFunctionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  tags: union(tags, { 'azd-service-name': 'blob-sharing-func' })
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { 
      '${identityId}': {}
    }
  }
  properties: {
    serverFarmId: flexFunctionPlan.id
    httpsOnly: true
    virtualNetworkSubnetId: integrationSubnetId
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${sourceStorageAccount.properties.primaryEndpoints.blob}${functionContainerName}'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: identityId
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 100
        instanceMemoryMB: 2048
      }
      runtime: {
        name: 'python'
        version: '3.11'
      }
    }
  }

  resource webConfig 'config' = {
    name: 'web'
    properties: {
      publicNetworkAccess: 'Enabled'
      ipSecurityRestrictionsDefaultAction: 'Deny'
      ipSecurityRestrictions:[
        {
          ipAddress: 'AzureEventGrid'
          action: 'Allow'
          tag: 'ServiceTag'
          priority: 300
          name: 'Allow Azure Event Grid'
        }
      ]
    }
  }

  resource appSettings 'config' = {
    name: 'appsettings'
    properties: {
      AzureWebJobsStorage__accountName: sourceStorageAccount.name
      AzureWebJobsStorage__clientId: identityClientId
      AzureWebJobsStorage__credential : 'managedidentity'
      AzureWebJobsFeatureFlags: 'EnableWorkerIndexing'
      AZURE_CLIENT_ID: identityClientId
      SOURCE_STORAGE_ACCOUNT_NAME: sourceStorageAccount.name
    }
  }
}

// Storage Blob Data Owner
resource sourceStorageRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(sourceStorageAccount.id, principalID, 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
  scope: sourceStorageAccount
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
    principalId: principalID
    principalType: 'ServicePrincipal'
  }
}

// Cognitive Services Contributor for Document Intelligence
resource cognitiveServicesRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(documentIntelligence.id, principalID, '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68')
  scope: documentIntelligence
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68')
    principalId: principalID
    principalType: 'ServicePrincipal'
  }
}

// Cognitive Services User for Document Intelligence
resource cognitiveServicesUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(documentIntelligence.id, principalID, 'a97b65f3-24c7-4388-baec-2e87135dc908')
  scope: documentIntelligence
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')
    principalId: principalID
    principalType: 'ServicePrincipal'
  }
}


// Cognitive Services OpenAI User
resource cognitiveServicesOAIUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(openAI.id, principalID, '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  scope: openAI
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
    principalId: principalID
    principalType: 'ServicePrincipal'
  }
}

