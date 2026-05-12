using '../main.bicep'

param namePrefix = 'contoso-dev'
param environment = 'dev'
param location = 'eastus'

param kubernetesVersion = '1.29'
param nodeVmSize = 'Standard_DS2_v2'
param systemNodeCount = 1
param minNodeCount = 1
param maxNodeCount = 3
param enableAutoScaling = true

// Leave empty for dev — uses kubenet. Set to a subnet resource ID to use Azure CNI.
// Example (from hub-spoke-vnet output): /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/contoso-dev-workload-a-vnet/subnets/app
param subnetId = ''

param serviceCidr = '172.16.0.0/16'
param dnsServiceIP = '172.16.0.10'
param enablePrivateCluster = false
param adminGroupObjectIds = []
param logRetentionDays = 30
