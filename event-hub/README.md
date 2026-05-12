# event-hub

Deploys an Azure Event Hubs namespace with configurable event hubs, per-hub consumer groups, and optional diagnostic settings.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  Event Hubs Namespace  (<namePrefix>-ehns)                       │
│  SKU: Standard  ·  TLS 1.2 minimum  ·  zone-redundant (opt)     │
│                                                                  │
│  ┌───────────────────────────────┐  ┌────────────────────────┐  │
│  │  Event Hub: telemetry         │  │  Event Hub: orders     │  │
│  │  partitions: 4                │  │  partitions: 2         │  │
│  │  retention: 1 day             │  │  retention: 7 days     │  │
│  │  ┌────────────┐ ┌──────────┐  │  │  ┌─────────────────┐  │  │
│  │  │ analytics  │ │ storage  │  │  │  │  fulfillment    │  │  │
│  │  └────────────┘ └──────────┘  │  │  └─────────────────┘  │  │
│  │  consumer groups              │  │  consumer groups       │  │
│  └───────────────────────────────┘  └────────────────────────┘  │
│                                                                  │
│  Diagnostic Settings ──► Log Analytics Workspace (optional)     │
└──────────────────────────────────────────────────────────────────┘
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `location` | string | resource group location | Azure region |
| `environment` | `'dev'` \| `'staging'` \| `'prod'` | `'dev'` | Environment tag |
| `namePrefix` | string | — | Prefix for all resource names. Must produce a globally unique namespace name (6–50 chars, alphanumeric and hyphens) |
| `sku` | `'Basic'` \| `'Standard'` \| `'Premium'` | `'Standard'` | Namespace SKU |
| `capacity` | int | `1` | Throughput units (Basic/Standard, max 40) or processing units (Premium, max 16) |
| `enableAutoInflate` | bool | `false` | Auto-scale throughput units. Standard SKU only |
| `maxThroughputUnits` | int | `10` | Auto-inflate ceiling. Ignored when `enableAutoInflate` is false |
| `zoneRedundant` | bool | `false` | Enable availability zone redundancy |
| `disableLocalAuth` | bool | `false` | Disable SAS keys; require AAD authentication only |
| `eventHubs` | `eventHubConfig[]` | `[]` | Event Hub definitions (see below) |
| `logAnalyticsWorkspaceId` | string | `''` | Resource ID of a Log Analytics workspace. Leave empty to skip diagnostic settings |

### eventHubConfig shape

```bicep
{
  name: string               // Event Hub name
  partitionCount: int        // 1–32 (Standard); 1–2048 (Premium)
  messageRetentionDays: int  // 1–7 (Standard); up to 90 with Premium
  consumerGroups: [
    { name: string }         // Consumer group name (in addition to $Default)
  ]
}
```

> **Note:** The built-in `$Default` consumer group is created automatically by Azure and is not managed by this module.

## Outputs

| Output | Type | Description |
|---|---|---|
| `namespaceId` | string | Resource ID of the Event Hubs namespace |
| `namespaceName` | string | Namespace name |
| `namespaceHostname` | string | AMQP/HTTPS hostname (`<name>.servicebus.windows.net`) |
| `eventHubNames` | string[] | Names of all created event hubs (index-aligned with `eventHubs` param) |

## SKU Comparison

| Feature | Basic | Standard | Premium |
|---|---|---|---|
| Consumer groups | 1 ($Default) | 20 | 100 |
| Max throughput units | 20 | 40 | 16 PUs |
| Auto-inflate | No | Yes | No |
| Message retention | 1 day | 7 days | 90 days |
| Private endpoints | No | No | Yes |
| Schema Registry | No | No | Yes |
| Zone redundancy | No | No | Yes |

## Authentication

| Mode | `disableLocalAuth` | Notes |
|---|---|---|
| SAS keys + AAD | `false` (default) | Convenient for dev; SAS keys are shared secrets |
| AAD only | `true` | Recommended for production; use managed identity or workload identity to connect |

To grant a managed identity access to send or receive events, assign one of these built-in roles:

```bash
# Send events
az role assignment create \
  --role "Azure Event Hubs Data Sender" \
  --assignee <principal-id> \
  --scope <namespaceId>

# Receive events
az role assignment create \
  --role "Azure Event Hubs Data Receiver" \
  --assignee <principal-id> \
  --scope <namespaceId>
```

## Linking to Other Modules

Pass the `aks-cluster` Log Analytics workspace output to enable Container Insights correlation:

```bicep
module eventHub 'event-hub/main.bicep' = {
  params: {
    logAnalyticsWorkspaceId: aksClusterModule.outputs.logAnalyticsWorkspaceId
  }
}
```

## Deployment

```bash
# Validate
az deployment group validate \
  --resource-group <rg-name> \
  --template-file event-hub/main.bicep \
  --parameters event-hub/parameters/dev.bicepparam

# Deploy
az deployment group create \
  --resource-group <rg-name> \
  --template-file event-hub/main.bicep \
  --parameters event-hub/parameters/dev.bicepparam
```

## AZ-305 / AZ-400 Alignment

| Exam | Objective | Coverage |
|---|---|---|
| AZ-305 | Design a data storage solution for non-relational data | Event Hubs as a streaming ingestion tier |
| AZ-305 | Design for high availability | Zone redundancy; auto-inflate for throughput spikes |
| AZ-305 | Design for security | TLS 1.2 minimum; AAD-only auth via `disableLocalAuth` |
| AZ-305 | Design a solution for logging and monitoring | Diagnostic settings → Log Analytics for operational visibility |
| AZ-305 | Design a messaging solution | Consumer groups enabling independent downstream processors |
| AZ-400 | Implement infrastructure as code | Typed parameters; flatten pattern for nested resource loops |
