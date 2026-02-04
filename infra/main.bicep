// ============================================================================
// Azure Synapse CDC POC - Infrastructure as Code (Bicep)
// ============================================================================
// This template deploys:
// - Azure Storage Account (ADLS Gen2 enabled)
// - Azure Synapse Analytics Workspace
// - Required RBAC role assignments for Synapse to access Storage
//
// Naming Convention:
// All resource names are derived from the projectName parameter:
// - Resource Group: rg-{projectName}
// - Storage Account: {projectName}st (lowercase, no dashes, max 24 chars)
// - Synapse Workspace: {projectName}-syn
// ============================================================================

@description('Location for all resources')
param location string = resourceGroup().location

@description('Project name used to generate all resource names (e.g., "fantastic-demo")')
@minLength(3)
@maxLength(20)
param projectName string

@description('SQL Administrator Login for Synapse')
param sqlAdminLogin string = 'sqladmin'

@description('SQL Administrator Password for Synapse')
@secure()
param sqlAdminPassword string

// ============================================================================
// Variables - All names derived from projectName
// ============================================================================

// Storage account: lowercase, no dashes, append 'st', max 24 chars
var storageAccountNameClean = toLower(replace(projectName, '-', ''))
var storageAccountName = take('${storageAccountNameClean}st', 24)

// Synapse workspace: lowercase with dashes allowed, append '-syn'
var synapseWorkspaceName = toLower('${projectName}-syn')

// Container names
var defaultDataLakeStorageFilesystemName = 'synapsefs'

// ============================================================================
// Storage Account (ADLS Gen2)
// ============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    isHnsEnabled: true  // Enable Hierarchical Namespace for ADLS Gen2
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Blob Services
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

// Container for Synapse workspace
resource synapseContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobServices
  name: defaultDataLakeStorageFilesystemName
}

// Container for data (source, destination, metadata)
resource dataContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobServices
  name: 'data'
}

// ============================================================================
// Synapse Analytics Workspace
// ============================================================================

resource synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: synapseWorkspaceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    defaultDataLakeStorage: {
      resourceId: storageAccount.id
      accountUrl: 'https://${storageAccount.name}.dfs.${environment().suffixes.storage}'
      filesystem: defaultDataLakeStorageFilesystemName
    }
    sqlAdministratorLogin: sqlAdminLogin
    sqlAdministratorLoginPassword: sqlAdminPassword
    managedVirtualNetwork: 'default'
    managedResourceGroupName: 'rg-${projectName}-managed'
    publicNetworkAccess: 'Enabled'
  }
}

// Synapse Firewall Rule - Allow All Azure Services
resource synapseFirewallAllowAzure 'Microsoft.Synapse/workspaces/firewallRules@2021-06-01' = {
  parent: synapseWorkspace
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Synapse Firewall Rule - Allow All (for POC purposes)
resource synapseFirewallAllowAll 'Microsoft.Synapse/workspaces/firewallRules@2021-06-01' = {
  parent: synapseWorkspace
  name: 'AllowAll'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

// ============================================================================
// RBAC Role Assignments
// ============================================================================

// Storage Blob Data Contributor role for Synapse Managed Identity
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource synapseStorageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, synapseWorkspace.id, storageBlobDataContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: synapseWorkspace.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// Outputs
// ============================================================================

output projectName string = projectName
output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
output storageAccountDfsEndpoint string = 'https://${storageAccount.name}.dfs.${environment().suffixes.storage}'
output synapseWorkspaceName string = synapseWorkspace.name
output synapseWorkspaceId string = synapseWorkspace.id
output synapseSqlEndpoint string = synapseWorkspace.properties.connectivityEndpoints.sql
output synapseDevEndpoint string = synapseWorkspace.properties.connectivityEndpoints.dev
output synapseWebEndpoint string = 'https://web.azuresynapse.net?workspace=%2fsubscriptions%2f${subscription().subscriptionId}%2fresourceGroups%2f${resourceGroup().name}%2fproviders%2fMicrosoft.Synapse%2fworkspaces%2f${synapseWorkspace.name}'
output dataContainerPath string = 'abfss://data@${storageAccount.name}.dfs.${environment().suffixes.storage}'
