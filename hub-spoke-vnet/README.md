# hub-spoke-vnet

Deploys an Azure hub-spoke virtual network topology with bidirectional VNet peering.

## Architecture

```
                    ┌──────────────────────────────────────────────┐
                    │  Hub VNet  (10.0.0.0/16)                     │
                    │                                              │
                    │  ┌────────────────────┐                      │
                    │  │ AzureFirewallSubnet │  /26                 │
                    │  └────────────────────┘                      │
                    │  ┌────────────────────┐                      │
                    │  │ AzureBastionSubnet │  /26                 │
                    │  └────────────────────┘                      │
                    │  ┌────────────────────┐                      │
                    │  │ GatewaySubnet      │  /27                 │
                    │  └────────────────────┘                      │
                    │  ┌────────────────────┐                      │
                    │  │ management         │  /24  + NSG          │
                    │  └────────────────────┘                      │
                    └──────────────┬───────────────────────────────┘
                                   │  VNet Peering (bidirectional)
               ┌───────────────────┴───────────────────┐
               │                                       │
   ┌───────────▼────────────┐             ┌────────────▼───────────┐
   │ Spoke: workload-a      │             │ Spoke: workload-b      │
   │ 10.1.0.0/16            │             │ 10.2.0.0/16            │
   │  - app   10.1.0.0/24   │             │  - app   10.2.0.0/24   │
   │  - data  10.1.1.0/24   │             └────────────────────────┘
   └────────────────────────┘
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `location` | string | resource group location | Azure region for all resources |
| `environment` | `'dev'` \| `'staging'` \| `'prod'` | `'dev'` | Environment tag |
| `namePrefix` | string | — | Prefix applied to all resource names |
| `hubAddressPrefix` | string | `10.0.0.0/16` | Hub VNet address space |
| `firewallSubnetPrefix` | string | `10.0.0.0/26` | AzureFirewallSubnet — /26 minimum |
| `bastionSubnetPrefix` | string | `10.0.1.0/26` | AzureBastionSubnet — /26 minimum |
| `gatewaySubnetPrefix` | string | `10.0.2.0/27` | GatewaySubnet for VPN/ExpressRoute |
| `managementSubnetPrefix` | string | `10.0.3.0/24` | Hub management subnet |
| `spokes` | `spokeConfig[]` | `[]` | Array of spoke VNet definitions (see below) |

### spokeConfig shape

```bicep
{
  name: string           // used in resource name: <namePrefix>-<name>-vnet
  addressPrefix: string  // VNet address space
  subnets: [
    {
      name: string
      addressPrefix: string
    }
  ]
}
```

## Outputs

| Output | Type | Description |
|---|---|---|
| `hubVnetId` | string | Resource ID of the hub VNet |
| `hubVnetName` | string | Name of the hub VNet |
| `spokeVnetIds` | string[] | Resource IDs of all spoke VNets (index-aligned with `spokes` param) |
| `spokeVnetNames` | string[] | Names of all spoke VNets |
| `managementNsgId` | string | Resource ID of the management subnet NSG |

## Gateway Transit

By default `allowGatewayTransit` (hub) and `useRemoteGateways` (spokes) are both `false`. Once a VPN Gateway or ExpressRoute Gateway is deployed into `GatewaySubnet`, flip both flags to route spoke traffic through the hub gateway.

## Deployment

```bash
# Validate
az deployment group validate \
  --resource-group <rg-name> \
  --template-file hub-spoke-vnet/main.bicep \
  --parameters hub-spoke-vnet/parameters/dev.bicepparam

# Deploy
az deployment group create \
  --resource-group <rg-name> \
  --template-file hub-spoke-vnet/main.bicep \
  --parameters hub-spoke-vnet/parameters/dev.bicepparam
```

## AZ-305 Alignment

**Domain:** Design network connectivity solutions

| Objective | Coverage |
|---|---|
| Design hub-spoke network topology | Hub VNet with shared-services subnets + spoke peering |
| Plan for Azure Firewall | `AzureFirewallSubnet` pre-provisioned (/26) |
| Plan for Azure Bastion | `AzureBastionSubnet` pre-provisioned (/26) |
| Plan for VPN / ExpressRoute Gateway | `GatewaySubnet` pre-provisioned (/27) |
| Apply network segmentation | Per-spoke subnets; management NSG on hub |
| Enable transitive routing via hub | Gateway transit flags documented and ready |
