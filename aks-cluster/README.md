# aks-cluster

Deploys a production-grade Azure Kubernetes Service cluster with RBAC, AAD integration, OIDC issuer, workload identity, Container Insights, and Azure Policy.

## Architecture

```
                    ┌──────────────────────────────────────────────────┐
                    │  Resource Group                                  │
                    │                                                  │
                    │  ┌─────────────────────────────────────────────┐ │
                    │  │  AKS Managed Cluster                        │ │
                    │  │                                             │ │
                    │  │  ┌──────────────────┐  ┌─────────────────┐ │ │
                    │  │  │  System Node Pool │  │  AAD RBAC       │ │ │
                    │  │  │  (auto-scale)     │  │  OIDC Issuer    │ │ │
                    │  │  └──────────────────┘  │  Workload ID    │ │ │
                    │  │                         └─────────────────┘ │ │
                    │  │  Addons: omsagent · azurepolicy             │ │
                    │  └─────────────────────────────────────────────┘ │
                    │                                                  │
                    │  ┌──────────────────────┐                       │
                    │  │  User-Assigned MI     │  kubelet identity     │
                    │  └──────────────────────┘                       │
                    │                                                  │
                    │  ┌──────────────────────┐                       │
                    │  │  Log Analytics WS    │  Container Insights   │
                    │  └──────────────────────┘                       │
                    └──────────────────────────────────────────────────┘
```

## Network Modes

| `subnetId` | Network Plugin | Network Policy | Notes |
|---|---|---|---|
| *(empty)* | kubenet | none | Dev default — no VNet dependency |
| *(provided)* | Azure CNI | azure | Production — nodes get VNet IPs |

To use Azure CNI, pass the `subnetId` output from [hub-spoke-vnet](../hub-spoke-vnet/README.md):

```bicep
param subnetId = hubSpokeModule.outputs.spokeVnetIds[0]  // then reference the specific subnet
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `location` | string | resource group location | Azure region |
| `environment` | `'dev'` \| `'staging'` \| `'prod'` | `'dev'` | Environment tag |
| `namePrefix` | string | — | Prefix applied to all resource names |
| `kubernetesVersion` | string | `'1.29'` | Kubernetes version |
| `nodeVmSize` | string | `'Standard_DS2_v2'` | VM size for system node pool |
| `systemNodeCount` | int | `2` | Initial node count |
| `minNodeCount` | int | `1` | Auto-scale minimum |
| `maxNodeCount` | int | `5` | Auto-scale maximum |
| `enableAutoScaling` | bool | `true` | Enable cluster auto-scaler |
| `subnetId` | string | `''` | Subnet resource ID for Azure CNI; empty = kubenet |
| `serviceCidr` | string | `172.16.0.0/16` | Kubernetes service CIDR (must not overlap VNet) |
| `dnsServiceIP` | string | `172.16.0.10` | Cluster DNS IP (must be within `serviceCidr`) |
| `enablePrivateCluster` | bool | `false` | Private API server endpoint |
| `adminGroupObjectIds` | string[] | `[]` | AAD group IDs granted Cluster Admin |
| `logRetentionDays` | int | `30` | Log Analytics retention (30–730 days) |

## Outputs

| Output | Type | Description |
|---|---|---|
| `clusterName` | string | AKS cluster name |
| `clusterId` | string | AKS cluster resource ID |
| `clusterFqdn` | string | Public API server FQDN |
| `kubeletIdentityObjectId` | string | Object ID of the kubelet managed identity |
| `oidcIssuerUrl` | string | OIDC issuer URL (used to configure workload identity federation) |
| `logAnalyticsWorkspaceId` | string | Resource ID of the Log Analytics workspace |
| `aksIdentityPrincipalId` | string | Principal ID of the user-assigned managed identity |

## Workload Identity Pattern

With OIDC issuer and workload identity enabled, pods can authenticate to Azure services without secrets:

```bash
# Create a federated credential for a service account
az identity federated-credential create \
  --name my-app-federated \
  --identity-name <namePrefix>-aks-identity \
  --resource-group <rg-name> \
  --issuer <oidcIssuerUrl> \
  --subject system:serviceaccount:<namespace>:<service-account-name>
```

## Deployment

```bash
# Validate
az deployment group validate \
  --resource-group <rg-name> \
  --template-file aks-cluster/main.bicep \
  --parameters aks-cluster/parameters/dev.bicepparam

# Deploy
az deployment group create \
  --resource-group <rg-name> \
  --template-file aks-cluster/main.bicep \
  --parameters aks-cluster/parameters/dev.bicepparam

# Get credentials
az aks get-credentials \
  --resource-group <rg-name> \
  --name <namePrefix>-aks
```

## AZ-305 / AZ-400 Alignment

| Exam | Objective | Coverage |
|---|---|---|
| AZ-305 | Design a compute solution using containers | AKS managed cluster with system node pool and auto-scaling |
| AZ-305 | Design for authentication and authorization | AAD-managed RBAC, Azure RBAC integration, admin group binding |
| AZ-305 | Design a solution for logging and monitoring | Container Insights via omsagent addon + Log Analytics |
| AZ-305 | Design network connectivity for AKS | kubenet / Azure CNI toggle; private cluster option |
| AZ-305 | Design for security | Workload identity (no secret-based auth), Azure Policy addon |
| AZ-400 | Implement infrastructure as code | Full Bicep parameterization with typed arrays and conditionals |
| AZ-400 | Implement a secure DevOps pipeline | OIDC issuer enables keyless federation from CI/CD systems |
