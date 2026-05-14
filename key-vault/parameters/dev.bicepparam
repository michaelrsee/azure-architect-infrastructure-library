using '../main.bicep'

param namePrefix = 'contoso-dev'
param environment = 'dev'
param location = 'eastus'

param sku = 'standard'
param softDeleteRetentionDays = 7

// enablePurgeProtection is irreversible — keep false for dev so the vault can be freely deleted.
// Set to true for staging/prod.
param enablePurgeProtection = false

// Populate from the aks-cluster module output: aksClusterModule.outputs.kubeletIdentityObjectId
// Or retrieve with: az aks show --name <cluster-name> --resource-group <rg> --query identityProfile.kubeletidentity.objectId -o tsv
param aksKubeletIdentityObjectId = '00000000-0000-0000-0000-000000000000'

param keyVaultAdmins = []

// Open to all traffic in dev. For staging/prod, set defaultAction to 'Deny' and
// restrict to the AKS subnet from the hub-spoke-vnet module.
param networkAcls = {
  defaultAction: 'Allow'
  bypass: 'AzureServices'
  virtualNetworkSubnetIds: []
  ipAddressRanges: []
}

// Optionally wire to aks-cluster module output: aksClusterModule.outputs.logAnalyticsWorkspaceId
param logAnalyticsWorkspaceId = ''
