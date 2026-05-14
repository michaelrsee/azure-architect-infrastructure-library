targetScope = 'resourceGroup'

type vaultAdmin = {
  objectId: string
  principalType: 'User' | 'Group' | 'ServicePrincipal'
}

type networkAclConfig = {
  defaultAction: 'Allow' | 'Deny'
  // AzureServices bypass allows trusted Microsoft services (e.g. ARM template deployments, Defender)
  bypass: 'AzureServices' | 'None'
  virtualNetworkSubnetIds: string[]
  ipAddressRanges: string[]
}

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Environment tag applied to all resources.')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Name prefix. Key Vault names must be 3–24 characters and globally unique.')
param namePrefix string

@description('Key Vault SKU. Use premium for HSM-backed keys and certificates.')
@allowed(['standard', 'premium'])
param sku string = 'standard'

@description('Soft-delete retention period in days. Cannot be reduced once set.')
@minValue(7)
@maxValue(90)
param softDeleteRetentionDays int = 90

@description('Enable purge protection. WARNING: irreversible once enabled. Prevents deletion of the vault or its objects during the retention period. Required for production.')
param enablePurgeProtection bool = false

@description('Object ID of the AKS kubelet managed identity. Receives the Key Vault Secrets User role, enabling the Secrets Store CSI Driver to mount TLS certificates as volume files.')
param aksKubeletIdentityObjectId string

@description('AAD principals granted the Key Vault Administrator role for managing keys, secrets, and certificates.')
param keyVaultAdmins vaultAdmin[] = []

@description('Network access control configuration. Default allows all traffic — restrict for staging/prod.')
param networkAcls networkAclConfig = {
  defaultAction: 'Allow'
  bypass: 'AzureServices'
  virtualNetworkSubnetIds: []
  ipAddressRanges: []
}

@description('Resource ID of a Log Analytics workspace for diagnostic settings. Leave empty to skip.')
param logAnalyticsWorkspaceId string = ''

var tags = {
  environment: environment
  managedBy: 'bicep'
  pattern: 'key-vault'
}

// Built-in role: Key Vault Secrets User
// Allows reading secret values, including the secret representation of certificates — required by the Secrets Store CSI Driver.
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

// Built-in role: Key Vault Administrator
// Full data-plane access to keys, secrets, and certificates.
var keyVaultAdministratorRoleId = '00482a5a-887f-4fb3-b363-3b7fe8e74483'

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: '${namePrefix}-kv'
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: sku
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionDays
    enablePurgeProtection: enablePurgeProtection
    // Legacy access policy flags intentionally false — RBAC is the authoritative access model
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    networkAcls: {
      defaultAction: networkAcls.defaultAction
      bypass: networkAcls.bypass
      virtualNetworkRules: [for subnetId in networkAcls.virtualNetworkSubnetIds: {
        id: subnetId
      }]
      ipRules: [for ipRange in networkAcls.ipAddressRanges: {
        value: ipRange
      }]
    }
  }
}

// Grants the AKS kubelet identity permission to read secret values.
// The Secrets Store CSI Driver runs as the kubelet identity and requires this role
// to fetch certificates and mount them into pods as volume files.
resource aksKubeletRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, aksKubeletIdentityObjectId, keyVaultSecretsUserRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: aksKubeletIdentityObjectId
    principalType: 'ServicePrincipal'
  }
}

resource adminRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for admin in keyVaultAdmins: {
  scope: keyVault
  name: guid(keyVault.id, admin.objectId, keyVaultAdministratorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultAdministratorRoleId)
    principalId: admin.objectId
    principalType: admin.principalType
  }
}]

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: '${namePrefix}-kv-diag'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
