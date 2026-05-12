# policy-governance

Deploys a custom Azure Policy initiative (policy set definition) and assigns it to the current subscription. Supports audit-only (`DoNotEnforce`) and active enforcement modes, with optional managed identity for remediation tasks.

> **Scope:** `subscription` — deploy with `az deployment sub create`, not `az deployment group create`.

## Architecture

```
Subscription scope
│
├── Policy Set Definition  (<namePrefix>-initiative)
│   ├── ref → Built-in Policy: Audit VMs without managed disks
│   ├── ref → Built-in Policy: Require secure transfer (storage)
│   └── ref → Built-in Policy: Disallow storage public access
│
├── Policy Assignment  (<namePrefix>-assignment)
│   ├── enforcementMode: DoNotEnforce | Default
│   ├── notScopes: [excluded resource IDs]
│   └── identity: SystemAssigned  ──────────────────────────────┐
│                                                               │
└── Role Assignment  (conditional — enableRemediationIdentity)  │
    └── Principal: assignment MI  ◄──────────────────────────────┘
        Role: Contributor (or custom remediationRoleDefinitionId)
```

## Policy Effects

Understanding effects is core to AZ-305. This module supports initiatives that combine any of:

| Effect | Behaviour | Identity needed? |
|---|---|---|
| `Audit` | Marks non-compliant; no action taken | No |
| `Deny` | Blocks the deployment request | No |
| `AuditIfNotExists` | Audits related resources that don't exist | No |
| `DeployIfNotExists` | Deploys a related resource to remediate | **Yes** |
| `Modify` | Adds or updates tags/properties on existing resources | **Yes** |

Set `enableRemediationIdentity: true` and `enforcementMode: 'Default'` when the initiative includes `DeployIfNotExists` or `Modify` policies.

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `location` | string | — | Azure region for the assignment identity |
| `environment` | `'dev'` \| `'staging'` \| `'prod'` | `'dev'` | Environment tag |
| `namePrefix` | string | — | Prefix applied to all resource names |
| `initiativeDisplayName` | string | — | Display name for the initiative and its assignment |
| `initiativeDescription` | string | — | Description for the initiative |
| `policyDefinitionReferences` | `policyDefinitionReference[]` | — | Policies to bundle (see below) |
| `enforcementMode` | `'Default'` \| `'DoNotEnforce'` | `'DoNotEnforce'` | `DoNotEnforce` audits without blocking — recommended for dev |
| `notScopes` | string[] | `[]` | Resource IDs excluded from the assignment |
| `enableRemediationIdentity` | bool | `false` | Grant the assignment identity a role for remediation |
| `remediationRoleDefinitionId` | string | Contributor GUID | Role granted when `enableRemediationIdentity` is true |

### policyDefinitionReference shape

```bicep
{
  policyDefinitionReferenceId: string  // unique ID within the initiative
  policyDefinitionId: string           // full ARM resource ID of the built-in or custom policy
  parameters: object                   // ARM parameter format: { paramName: { value: <val> } }
}
```

Find built-in policy IDs:

```bash
az policy definition list \
  --query "[].{name:name, displayName:properties.displayName}" \
  -o table
```

## Outputs

| Output | Type | Description |
|---|---|---|
| `initiativeId` | string | Resource ID of the policy set definition |
| `initiativeName` | string | Name of the policy set definition |
| `assignmentId` | string | Resource ID of the policy assignment |
| `assignmentName` | string | Name of the policy assignment |
| `assignmentPrincipalId` | string | Principal ID of the assignment's system-assigned identity |

## Deployment

Policy governance deploys at **subscription** scope:

```bash
# Validate
az deployment sub validate \
  --location eastus \
  --template-file policy-governance/main.bicep \
  --parameters policy-governance/parameters/dev.bicepparam

# Deploy
az deployment sub create \
  --location eastus \
  --template-file policy-governance/main.bicep \
  --parameters policy-governance/parameters/dev.bicepparam
```

## Escalating from Dev to Prod

| Setting | Dev | Prod |
|---|---|---|
| `enforcementMode` | `DoNotEnforce` | `Default` |
| `enableRemediationIdentity` | `false` | `true` (if using DeployIfNotExists/Modify) |
| Scope | Subscription | Management group (adjust `targetScope`) |

## Creating a Remediation Task

After deploying with `enableRemediationIdentity: true`, trigger remediation for a specific policy:

```bash
az policy remediation create \
  --name remediate-<policy-ref-id> \
  --policy-assignment <assignmentName> \
  --definition-reference-id <policyDefinitionReferenceId> \
  --resource-group <rg-name>
```

## AZ-305 / AZ-400 Alignment

| Exam | Objective | Coverage |
|---|---|---|
| AZ-305 | Design a governance solution | Policy initiative bundles multiple controls under a single assignment |
| AZ-305 | Recommend when to use Azure Policy | Effect types documented; Audit vs Deny vs DeployIfNotExists tradeoffs |
| AZ-305 | Design for compliance | `DoNotEnforce` → `Default` promotion path mirrors real-world rollout |
| AZ-305 | Design an identity solution for governance | SystemAssigned identity on assignment; role scoped to subscription |
| AZ-400 | Implement security and compliance in pipelines | Subscription-scoped Bicep deployment; enforcementMode as a pipeline variable |
