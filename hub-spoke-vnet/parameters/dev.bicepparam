using '../main.bicep'

param namePrefix = 'contoso-dev'
param environment = 'dev'
param location = 'eastus'

param hubAddressPrefix = '10.0.0.0/16'
param firewallSubnetPrefix = '10.0.0.0/26'
param bastionSubnetPrefix = '10.0.1.0/26'
param gatewaySubnetPrefix = '10.0.2.0/27'
param managementSubnetPrefix = '10.0.3.0/24'

param spokes = [
  {
    name: 'workload-a'
    addressPrefix: '10.1.0.0/16'
    subnets: [
      {
        name: 'app'
        addressPrefix: '10.1.0.0/24'
      }
      {
        name: 'data'
        addressPrefix: '10.1.1.0/24'
      }
    ]
  }
  {
    name: 'workload-b'
    addressPrefix: '10.2.0.0/16'
    subnets: [
      {
        name: 'app'
        addressPrefix: '10.2.0.0/24'
      }
    ]
  }
]
