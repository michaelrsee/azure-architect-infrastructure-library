targetScope = 'resourceGroup'

// User-defined types for spoke configuration
type subnetConfig = {
  name: string
  addressPrefix: string
}

type spokeConfig = {
  name: string
  addressPrefix: string
  subnets: subnetConfig[]
}

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Environment tag applied to all resources.')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Name prefix used in all resource names.')
param namePrefix string

@description('Address space for the hub VNet.')
param hubAddressPrefix string = '10.0.0.0/16'

@description('Address prefix for AzureFirewallSubnet. Must be /26 or larger.')
param firewallSubnetPrefix string = '10.0.0.0/26'

@description('Address prefix for AzureBastionSubnet. Must be /26 or larger.')
param bastionSubnetPrefix string = '10.0.1.0/26'

@description('Address prefix for GatewaySubnet.')
param gatewaySubnetPrefix string = '10.0.2.0/27'

@description('Address prefix for the hub management subnet.')
param managementSubnetPrefix string = '10.0.3.0/24'

@description('Spoke VNet configurations.')
param spokes spokeConfig[] = []

var tags = {
  environment: environment
  managedBy: 'bicep'
  pattern: 'hub-spoke'
}

// NSG for the management subnet — no rules by default, customise per environment
resource managementNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${namePrefix}-mgmt-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource hubVnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: '${namePrefix}-hub-vnet'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [hubAddressPrefix]
    }
    subnets: [
      {
        // Reserved name required by Azure Firewall
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: firewallSubnetPrefix
        }
      }
      {
        // Reserved name required by Azure Bastion
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
      {
        // Reserved name required by VPN / ExpressRoute Gateway
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: gatewaySubnetPrefix
        }
      }
      {
        name: 'management'
        properties: {
          addressPrefix: managementSubnetPrefix
          networkSecurityGroup: {
            id: managementNsg.id
          }
        }
      }
    ]
  }
}

resource spokeVnets 'Microsoft.Network/virtualNetworks@2023-09-01' = [for spoke in spokes: {
  name: '${namePrefix}-${spoke.name}-vnet'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [spoke.addressPrefix]
    }
    subnets: [for subnet in spoke.subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
      }
    }]
  }
}]

// Hub -> Spoke peering
// allowGatewayTransit: set to true once a VPN/ExpressRoute Gateway is deployed in the hub
resource hubToSpokePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = [for (spoke, i) in spokes: {
  parent: hubVnet
  name: 'hub-to-${spoke.name}'
  properties: {
    remoteVirtualNetwork: {
      id: spokeVnets[i].id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}]

// Spoke -> Hub peering
// useRemoteGateways: set to true (paired with hub allowGatewayTransit) when routing via hub gateway
resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = [for (spoke, i) in spokes: {
  parent: spokeVnets[i]
  name: '${spoke.name}-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}]

output hubVnetId string = hubVnet.id
output hubVnetName string = hubVnet.name
output spokeVnetIds string[] = [for (spoke, i) in spokes: spokeVnets[i].id]
output spokeVnetNames string[] = [for spoke in spokes: '${namePrefix}-${spoke.name}-vnet']
output managementNsgId string = managementNsg.id
