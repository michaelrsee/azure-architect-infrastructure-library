# log-analytics-workspace

Deploys a shared Azure Log Analytics workspace with configurable retention, ingestion cap, resource-context access control, and optional OMS solutions. Intended as the central observability sink for all modules in this library.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  Resource Group                                                  │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Log Analytics Workspace  (<namePrefix>-law)               │  │
│  │  SKU: PerGB2018 | CapacityReservation                      │  │
│  │  Retention: 30–730 days  ·  Daily cap: configurable        │  │
│  │  Access: resource-context permissions                      │  │
│  │                                                            │  │
│  │  OMS Solutions (optional)                                  │  │
│  │  ├── ContainerInsights(<namePrefix>-law)                   │  │
│  │  ├── Security(<namePrefix>-law)                            │  │
│  │  └── Updates(<namePrefix>-law)                             │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘

Downstream modules pass workspaceId as their logAnalyticsWorkspaceId parameter:

  log-analytics-workspace ──► workspaceId ──► aks-cluster
                                         ──► key-vault
                                         ──► event-hub
```

## Shared Workspace Pattern

Deploy this module first, then pass its outputs to other modules:

```bicep
module law 'log-analytics-workspace/main.bicep' = {
  name: 'law'
  params: {
    namePrefix: namePrefix
    environment: environment
    solutions: [
      { name: 'ContainerInsights', product: 'OMSGallery/ContainerInsights', publisher: 'Microsoft' }
    ]
  }
}

module aksCluster 'aks-cluster/main.bicep' = {
  name: 'aks-cluster'
  params: {
    logAnalyticsWorkspaceId: law.outputs.workspaceId
    // ...
  }
}

module keyVault 'key-vault/main.bicep' = {
  name: 'key-vault'
  params: {
    logAnalyticsWorkspaceId: law.outputs.workspaceId
    // ...
  }
}

module eventHub 'event-hub/main.bicep' = {
  name: 'event-hub'
  params: {
    logAnalyticsWorkspaceId: law.outputs.workspaceId
    // ...
  }
}
```

> **Note:** The `aks-cluster` module deploys its own internal workspace when `logAnalyticsWorkspaceId` is not provided. Using this shared workspace instead consolidates all logs into a single pane of glass.

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `location` | string | resource group location | Azure region |
| `environment` | `'dev'` \| `'staging'` \| `'prod'` | `'dev'` | Environment tag |
| `namePrefix` | string | — | Prefix for all resource names |
| `sku` | `'PerGB2018'` \| `'CapacityReservation'` | `'PerGB2018'` | Pay-as-you-go or commitment tier |
| `capacityReservationLevel` | int | `100` | GB/day commitment. One of: 100, 200, 300, 400, 500, 1000, 2000, 5000. Only applies when `sku` is `CapacityReservation` |
| `retentionInDays` | int | `30` | Interactive retention period (30–730 days). Data remains queryable for this duration |
| `dailyQuotaGb` | int | `-1` | Ingestion cap in GB/day. `-1` = unlimited. Use a positive value in dev to control costs |
| `enableResourcePermissions` | bool | `true` | Resource-context access — users see only logs for resources they have RBAC access to |
| `publicNetworkAccessForIngestion` | `'Enabled'` \| `'Disabled'` | `'Enabled'` | Disable to restrict ingestion to private endpoints only |
| `publicNetworkAccessForQuery` | `'Enabled'` \| `'Disabled'` | `'Enabled'` | Disable to restrict queries to private endpoints only |
| `solutions` | `omsSolution[]` | `[]` | OMS solutions to install (see below) |

### omsSolution shape

```bicep
{
  name: string      // solution identifier, e.g. 'ContainerInsights'
  product: string   // gallery path, e.g. 'OMSGallery/ContainerInsights'
  publisher: string // always 'Microsoft' for built-in solutions
}
```

### Common OMS Solutions

| Solution | name | product |
|---|---|---|
| Container Insights | `ContainerInsights` | `OMSGallery/ContainerInsights` |
| Microsoft Defender | `Security` | `OMSGallery/Security` |
| Update Management | `Updates` | `OMSGallery/Updates` |
| Change Tracking | `ChangeTracking` | `OMSGallery/ChangeTracking` |

## Outputs

| Output | Type | Description |
|---|---|---|
| `workspaceId` | string | Resource ID — pass as `logAnalyticsWorkspaceId` to other modules |
| `workspaceName` | string | Workspace name |
| `workspaceCustomerId` | string | Workspace GUID used by agents, SDKs, and diagnostic integrations |

## SKU Selection

| Scenario | SKU | Notes |
|---|---|---|
| Dev / variable workloads | `PerGB2018` | Pay per GB ingested; no commitment |
| Predictable high-volume ingestion (≥ 100 GB/day) | `CapacityReservation` | ~25% cheaper at scale; commitment required |

## Data Retention

| Tier | Behaviour | Cost |
|---|---|---|
| Interactive (this parameter) | Data is fully queryable | Included in SKU |
| Long-term (archive) | Data searchable but not ad-hoc queryable | Lower cost per GB |

To configure long-term archive retention beyond 730 days, set per-table retention via the Azure Portal or a separate `Microsoft.OperationalInsights/workspaces/tables` resource.

## Access Control Modes

| Mode | `enableResourcePermissions` | Behaviour |
|---|---|---|
| Workspace permissions | `false` | Explicit workspace-level RBAC grant required to query any logs |
| Resource permissions | `true` (default) | Users see logs for resources they already have access to — zero-trust aligned |

## Deployment

```bash
az deployment group create \
  --resource-group <rg-name> \
  --template-file log-analytics-workspace/main.bicep \
  --parameters log-analytics-workspace/parameters/dev.bicepparam
```

## AZ-305 / AZ-400 Alignment

| Exam | Objective | Coverage |
|---|---|---|
| AZ-305 | Design a monitoring solution | Central workspace aggregates logs from AKS, Key Vault, and Event Hubs |
| AZ-305 | Design for cost optimisation | Daily cap prevents runaway ingestion costs; CapacityReservation for high-volume |
| AZ-305 | Recommend a logging retention solution | `retentionInDays` with archive-tier guidance for long-term compliance |
| AZ-305 | Design for security | Resource-context permissions enforce least-privilege log access |
| AZ-305 | Design a high availability solution | CapacityReservation SKU supports cross-region workspace replication (portal) |
| AZ-400 | Implement monitoring and feedback | `workspaceId` output wires directly into all other module diagnostic settings |
