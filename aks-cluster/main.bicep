targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Environment tag applied to all resources.')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Name prefix used in all resource names.')
param namePrefix string

@description('Kubernetes version for the cluster.')
param kubernetesVersion string = '1.29'

@description('VM size for system node pool nodes.')
param nodeVmSize string = 'Standard_DS2_v2'

@description('Initial node count for the system node pool.')
@minValue(1)
@maxValue(100)
param systemNodeCount int = 2

@description('Minimum node count when auto-scaling is enabled.')
@minValue(1)
param minNodeCount int = 1

@description('Maximum node count when auto-scaling is enabled.')
@maxValue(100)
param maxNodeCount int = 5

@description('Enable cluster auto-scaler on the system node pool.')
param enableAutoScaling bool = true

@description('Resource ID of the subnet for Azure CNI. Leave empty to use kubenet (suitable for dev).')
param subnetId string = ''

@description('Kubernetes service address range. Must not overlap with the VNet address space.')
param serviceCidr string = '172.16.0.0/16'

@description('IP address for the Kubernetes DNS service. Must be within serviceCidr.')
param dnsServiceIP string = '172.16.0.10'

@description('Enable private cluster API server endpoint.')
param enablePrivateCluster bool = false

@description('AAD group object IDs granted the Cluster Admin role.')
param adminGroupObjectIds string[] = []

@description('Log Analytics workspace retention in days.')
@minValue(30)
@maxValue(730)
param logRetentionDays int = 30

var tags = {
  environment: environment
  managedBy: 'bicep'
  pattern: 'aks-cluster'
}

var clusterName = '${namePrefix}-aks'
// kubenet for standalone dev; Azure CNI when a subnet is provided
var networkPlugin = empty(subnetId) ? 'kubenet' : 'azure'

resource aksIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${namePrefix}-aks-identity'
  location: location
  tags: tags
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${namePrefix}-aks-law'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logRetentionDays
  }
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: clusterName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${aksIdentity.id}': {}
    }
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: clusterName
    enableRBAC: true
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      adminGroupObjectIDs: adminGroupObjectIds
    }
    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        count: systemNodeCount
        minCount: enableAutoScaling ? minNodeCount : null
        maxCount: enableAutoScaling ? maxNodeCount : null
        enableAutoScaling: enableAutoScaling
        vmSize: nodeVmSize
        osType: 'Linux'
        osDiskSizeGB: 0
        maxPods: networkPlugin == 'azure' ? 30 : 110
        vnetSubnetID: empty(subnetId) ? null : subnetId
      }
    ]
    networkProfile: {
      networkPlugin: networkPlugin
      networkPolicy: networkPlugin == 'azure' ? 'azure' : 'none'
      loadBalancerSku: 'standard'
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIP
    }
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
    apiServerAccessProfile: {
      enablePrivateCluster: enablePrivateCluster
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspace.id
        }
      }
      azurepolicy: {
        enabled: true
      }
    }
  }
}

output clusterName string = aksCluster.name
output clusterId string = aksCluster.id
output clusterFqdn string = aksCluster.properties.fqdn
output kubeletIdentityObjectId string = aksCluster.properties.identityProfile.kubeletidentity.objectId
output oidcIssuerUrl string = aksCluster.properties.oidcIssuerProfile.issuerURL
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output aksIdentityPrincipalId string = aksIdentity.properties.principalId
