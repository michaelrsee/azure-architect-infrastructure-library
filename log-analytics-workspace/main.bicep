targetScope = 'resourceGroup'

type omsSolution = {
  name: string     // e.g. 'ContainerInsights'
  product: string  // e.g. 'OMSGallery/ContainerInsights'
  publisher: string
}

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Environment tag applied to all resources.')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Name prefix used in all resource names.')
param namePrefix string

@description('Workspace SKU. PerGB2018 is pay-as-you-go; CapacityReservation commits to a fixed daily ingestion tier.')
@allowed(['PerGB2018', 'CapacityReservation'])
param sku string = 'PerGB2018'

@description('Commitment tier in GB/day. Only applies when sku is CapacityReservation.')
@allowed([100, 200, 300, 400, 500, 1000, 2000, 5000])
param capacityReservationLevel int = 100

@description('Interactive data retention in days. Data is queryable for this period.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Daily ingestion cap in GB. Set to -1 for unlimited. Use a positive value in dev to control costs.')
@minValue(-1)
param dailyQuotaGb int = -1

@description('Enable resource-context access control. Users see only logs for resources they have RBAC access to — aligns with least-privilege design.')
param enableResourcePermissions bool = true

@description('Allow log ingestion over the public internet.')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccessForIngestion string = 'Enabled'

@description('Allow log queries over the public internet.')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccessForQuery string = 'Enabled'

@description('OMS solutions to install into the workspace (e.g. ContainerInsights, Security, Updates).')
param solutions omsSolution[] = []

var tags = {
  environment: environment
  managedBy: 'bicep'
  pattern: 'log-analytics-workspace'
}

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${namePrefix}-law'
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
      // null omits the property when sku is PerGB2018 — ARM ignores it for that SKU anyway
      capacityReservationLevel: sku == 'CapacityReservation' ? capacityReservationLevel : null
    }
    retentionInDays: retentionInDays
    workspaceCapping: {
      dailyQuotaGb: dailyQuotaGb
    }
    publicNetworkAccessForIngestion: publicNetworkAccessForIngestion
    publicNetworkAccessForQuery: publicNetworkAccessForQuery
    features: {
      enableLogAccessUsingOnlyResourcePermissions: enableResourcePermissions
    }
  }
}

// OMS solutions extend the workspace with pre-built views and saved searches.
// The naming convention '<SolutionName>(<workspaceName>)' is required by Azure.
resource omsSolutions 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = [for sol in solutions: {
  name: '${sol.name}(${workspace.name})'
  location: location
  plan: {
    name: '${sol.name}(${workspace.name})'
    publisher: sol.publisher
    product: sol.product
    promotionCode: ''
  }
  properties: {
    workspaceResourceId: workspace.id
  }
}]

output workspaceId string = workspace.id
output workspaceName string = workspace.name
// customerId is the workspace GUID used by agents, SDKs, and SecretProviderClass references
output workspaceCustomerId string = workspace.properties.customerId
