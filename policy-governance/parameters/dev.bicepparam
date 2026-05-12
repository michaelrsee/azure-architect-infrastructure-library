using '../main.bicep'

param namePrefix = 'contoso-dev'
param environment = 'dev'
param location = 'eastus'

param initiativeDisplayName = 'Contoso Baseline Governance'
param initiativeDescription = 'Baseline security and operational hygiene policies for all Contoso subscriptions.'

// DoNotEnforce: evaluates compliance and surfaces findings without blocking deployments.
// Flip to 'Default' in staging/prod to actively enforce.
param enforcementMode = 'DoNotEnforce'

param notScopes = []
param enableRemediationIdentity = false

// Verify IDs for your tenant with: az policy definition list --query "[].{name:name, displayName:properties.displayName}" -o table
param policyDefinitionReferences = [
  {
    policyDefinitionReferenceId: 'AuditVMsManagedDisks'
    // Audit VMs that do not use managed disks
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/06a78e20-9358-41c9-923c-fb736d382a4d'
    parameters: {}
  }
  {
    policyDefinitionReferenceId: 'RequireStorageSecureTransfer'
    // Secure transfer to storage accounts should be enabled
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9'
    parameters: {}
  }
  {
    policyDefinitionReferenceId: 'AuditStoragePublicAccess'
    // Storage account public access should be disallowed
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/4fa4b6c0-31ca-4c0d-b10d-24b96f62a751'
    parameters: {}
  }
]
