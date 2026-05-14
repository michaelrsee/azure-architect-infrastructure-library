using '../main.bicep'

param namePrefix = 'contoso-dev'
param environment = 'dev'
param location = 'eastus'

param sku = 'PerGB2018'
param retentionInDays = 30

// 1 GB/day cap keeps dev costs predictable. Set to -1 for unlimited in staging/prod.
param dailyQuotaGb = 1

param enableResourcePermissions = true
param publicNetworkAccessForIngestion = 'Enabled'
param publicNetworkAccessForQuery = 'Enabled'

// ContainerInsights enables the AKS monitoring dashboards and recommended alerts in Azure Monitor.
// Pass workspaceId output to the aks-cluster module's logAnalyticsWorkspaceId parameter.
param solutions = [
  {
    name: 'ContainerInsights'
    product: 'OMSGallery/ContainerInsights'
    publisher: 'Microsoft'
  }
]
