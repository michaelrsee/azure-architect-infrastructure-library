using '../main.bicep'

param namePrefix = 'contoso-dev'
param environment = 'dev'
param location = 'eastus'

param sku = 'Standard'
param capacity = 1
param enableAutoInflate = false
param maxThroughputUnits = 10
param zoneRedundant = false
param disableLocalAuth = false

param eventHubs = [
  {
    name: 'telemetry'
    partitionCount: 4
    messageRetentionDays: 1
    consumerGroups: [
      { name: 'analytics' }
      { name: 'storage' }
    ]
  }
  {
    name: 'orders'
    partitionCount: 2
    messageRetentionDays: 7
    consumerGroups: [
      { name: 'fulfillment' }
    ]
  }
]

// Pass the logAnalyticsWorkspaceId output from aks-cluster or another module to enable diagnostics.
param logAnalyticsWorkspaceId = ''
