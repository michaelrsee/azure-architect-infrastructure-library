targetScope = 'resourceGroup'

type consumerGroupConfig = {
  name: string
}

type eventHubConfig = {
  name: string
  partitionCount: int
  messageRetentionDays: int
  consumerGroups: consumerGroupConfig[]
}

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Environment tag applied to all resources.')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Name prefix used in all resource names. Must produce a globally unique namespace name.')
param namePrefix string

@description('Event Hub namespace SKU.')
@allowed(['Basic', 'Standard', 'Premium'])
param sku string = 'Standard'

@description('Throughput units (Basic/Standard) or processing units (Premium). Max 10 for Basic, 40 for Standard, 16 for Premium.')
@minValue(1)
@maxValue(40)
param capacity int = 1

@description('Enable auto-inflate to automatically scale throughput units. Standard SKU only.')
param enableAutoInflate bool = false

@description('Upper bound for auto-inflate. Ignored when enableAutoInflate is false.')
@minValue(0)
@maxValue(40)
param maxThroughputUnits int = 10

@description('Enable availability zone redundancy for the namespace.')
param zoneRedundant bool = false

@description('Disable SAS key authentication and require AAD-only access. Recommended for production.')
param disableLocalAuth bool = false

@description('Event Hub definitions to create within the namespace.')
param eventHubs eventHubConfig[] = []

@description('Resource ID of a Log Analytics workspace for diagnostic settings. Leave empty to skip.')
param logAnalyticsWorkspaceId string = ''

var tags = {
  environment: environment
  managedBy: 'bicep'
  pattern: 'event-hub'
}

// Flatten hub + consumer group pairs so they can be deployed in a single resource loop.
// Bicep does not support nested resource loops, so we pre-compute the cross-product here.
var consumerGroupsFlat = flatten([for hub in eventHubs: [for cg in hub.consumerGroups: {
  hubName: hub.name
  cgName: cg.name
}]])

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2022-10-01-preview' = {
  name: '${namePrefix}-ehns'
  location: location
  tags: tags
  sku: {
    name: sku
    tier: sku
    capacity: capacity
  }
  properties: {
    isAutoInflateEnabled: sku == 'Standard' ? enableAutoInflate : false
    maximumThroughputUnits: (sku == 'Standard' && enableAutoInflate) ? maxThroughputUnits : 0
    zoneRedundant: zoneRedundant
    minimumTlsVersion: '1.2'
    disableLocalAuth: disableLocalAuth
  }
}

resource eventHubInstances 'Microsoft.EventHub/namespaces/eventhubs@2022-10-01-preview' = [for hub in eventHubs: {
  parent: eventHubNamespace
  name: hub.name
  properties: {
    partitionCount: hub.partitionCount
    messageRetentionInDays: hub.messageRetentionDays
  }
}]

// Consumer groups use the full name path (namespace/hub/group) because Bicep does not
// support parent references inside a loop that references another loop's output index.
resource consumerGroupInstances 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2022-10-01-preview' = [for cg in consumerGroupsFlat: {
  name: '${eventHubNamespace.name}/${cg.hubName}/${cg.cgName}'
  dependsOn: [eventHubInstances]
}]

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: '${namePrefix}-ehns-diag'
  scope: eventHubNamespace
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

output namespaceId string = eventHubNamespace.id
output namespaceName string = eventHubNamespace.name
output namespaceHostname string = '${eventHubNamespace.name}.servicebus.windows.net'
output eventHubNames string[] = [for hub in eventHubs: hub.name]
