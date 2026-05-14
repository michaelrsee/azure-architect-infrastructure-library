# key-vault

Deploys an Azure Key Vault with RBAC authorization, scoped access for the AKS kubelet identity, and optional network ACLs and diagnostic settings. Designed as the certificate store for TLS secrets consumed by the AKS Secrets Store CSI Driver.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  Resource Group                                                      │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  Key Vault  (<namePrefix>-kv)                                  │  │
│  │  RBAC: enabled  ·  Soft-delete  ·  TLS 1.2+  ·  SKU: standard │  │
│  │                                                                │  │
│  │  Role Assignments                                              │  │
│  │  ├── Key Vault Secrets User  → AKS kubelet identity           │  │
│  │  └── Key Vault Administrator → admin principals[]             │  │
│  │                                                                │  │
│  │  Network ACLs (optional)                                       │  │
│  │  ├── defaultAction: Allow | Deny                              │  │
│  │  ├── bypass: AzureServices                                    │  │
│  │  └── virtualNetworkRules: [AKS subnet ID, ...]               │  │
│  │                                                                │  │
│  │  Diagnostic Settings ──► Log Analytics Workspace (optional)   │  │
│  └────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘

AKS Cluster  (from aks-cluster module)
└── Secrets Store CSI Driver  (azure-keyvault-secrets-provider addon)
    └── SecretProviderClass
        ├── vaultUri: keyVaultUri output
        ├── objects: [{objectName: "my-tls-cert", objectType: "secret"}]
        └── tenantId: subscription().tenantId
            │
            ▼ Key Vault Secrets User role (kubelet identity)
        Key Vault ──► TLS cert mounted as volume ──► Pod
```

## TLS Certificate Flow

1. Import a certificate into Key Vault (once, manually or via pipeline):
   ```bash
   az keyvault certificate import \
     --vault-name <keyVaultName> \
     --name my-tls-cert \
     --file cert.pfx
   ```

2. Enable the Secrets Store CSI Driver addon on the AKS cluster:
   ```bash
   az aks enable-addons \
     --addons azure-keyvault-secrets-provider \
     --name <cluster-name> \
     --resource-group <rg-name>
   ```

3. Deploy a `SecretProviderClass` in the cluster:
   ```yaml
   apiVersion: secrets-store.csi.x-k8s.io/v1
   kind: SecretProviderClass
   metadata:
     name: my-tls-provider
   spec:
     provider: azure
     parameters:
       usePodIdentity: "false"
       useVMManagedIdentity: "true"
       userAssignedIdentityID: ""   # empty = kubelet system-assigned identity
       keyvaultName: <keyVaultName>
       objects: |
         array:
           - |
             objectName: my-tls-cert
             objectType: secret      # "secret" exposes the full PEM chain + private key
             objectVersion: ""
       tenantId: <tenantId>
   ```

4. Mount the `SecretProviderClass` as a volume in your pod and reference it in an `Ingress` TLS secret.

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `location` | string | resource group location | Azure region |
| `environment` | `'dev'` \| `'staging'` \| `'prod'` | `'dev'` | Environment tag |
| `namePrefix` | string | — | Prefix for all resource names. Key Vault name must be 3–24 chars and globally unique |
| `sku` | `'standard'` \| `'premium'` | `'standard'` | `premium` enables HSM-backed keys |
| `softDeleteRetentionDays` | int | `90` | 7–90 days. Cannot be reduced once set |
| `enablePurgeProtection` | bool | `false` | **Irreversible.** Prevents deletion of vault objects during retention period. Required for production |
| `aksKubeletIdentityObjectId` | string | — | Object ID of the AKS kubelet identity. Use the `kubeletIdentityObjectId` output from `aks-cluster` |
| `keyVaultAdmins` | `vaultAdmin[]` | `[]` | AAD principals granted Key Vault Administrator (see below) |
| `networkAcls` | `networkAclConfig` | Allow all | Network access restrictions (see below) |
| `logAnalyticsWorkspaceId` | string | `''` | Log Analytics resource ID for diagnostic settings |

### vaultAdmin shape

```bicep
{
  objectId: string
  principalType: 'User' | 'Group' | 'ServicePrincipal'
}
```

### networkAclConfig shape

```bicep
{
  defaultAction: 'Allow' | 'Deny'
  bypass: 'AzureServices' | 'None'
  virtualNetworkSubnetIds: string[]   // e.g. AKS subnet from hub-spoke-vnet
  ipAddressRanges: string[]           // CIDR or single IPs
}
```

## Outputs

| Output | Type | Description |
|---|---|---|
| `keyVaultId` | string | Resource ID of the Key Vault |
| `keyVaultName` | string | Key Vault name |
| `keyVaultUri` | string | Vault URI used in SecretProviderClass (`https://<name>.vault.azure.net/`) |

## Module Integration

Wire outputs directly from `aks-cluster` to eliminate manual ID lookups:

```bicep
module keyVault 'key-vault/main.bicep' = {
  name: 'key-vault'
  params: {
    aksKubeletIdentityObjectId: aksCluster.outputs.kubeletIdentityObjectId
    logAnalyticsWorkspaceId: aksCluster.outputs.logAnalyticsWorkspaceId
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      // Reference the AKS spoke subnet from hub-spoke-vnet
      virtualNetworkSubnetIds: [hubSpokeVnet.outputs.spokeVnetIds[0]]
      ipAddressRanges: []
    }
  }
}
```

## Dev → Prod Escalation

| Setting | Dev | Prod |
|---|---|---|
| `enablePurgeProtection` | `false` | `true` |
| `softDeleteRetentionDays` | `7` | `90` |
| `networkAcls.defaultAction` | `'Allow'` | `'Deny'` |
| `sku` | `'standard'` | `'premium'` (if HSM required) |
| `keyVaultAdmins` | `[]` | Ops/security AAD group |

## RBAC Roles

| Role | ID | Granted to |
|---|---|---|
| Key Vault Secrets User | `4633458b-…` | AKS kubelet identity — read secret values (including cert private keys) |
| Key Vault Administrator | `00482a5a-…` | `keyVaultAdmins` — full data-plane management |

> Access policies (`enabledForDeployment`, `enabledForTemplateDeployment`, `enabledForDiskEncryption`) are all disabled. RBAC is the sole access model.

## Deployment

```bash
az deployment group create \
  --resource-group <rg-name> \
  --template-file key-vault/main.bicep \
  --parameters key-vault/parameters/dev.bicepparam
```

## AZ-305 / AZ-400 Alignment

| Exam | Objective | Coverage |
|---|---|---|
| AZ-305 | Design a solution for storing secrets | Key Vault as the authoritative certificate store for TLS |
| AZ-305 | Design for authentication and authorization | RBAC-only access; least-privilege Secrets User role for kubelet |
| AZ-305 | Design for data protection | Soft-delete + purge protection; HSM option via premium SKU |
| AZ-305 | Design network security | Network ACLs with subnet-level allow-list and AzureServices bypass |
| AZ-305 | Design a monitoring solution | Diagnostic settings surface all vault operations to Log Analytics |
| AZ-400 | Integrate secrets into pipelines | `keyVaultUri` output feeds directly into SecretProviderClass manifests |
