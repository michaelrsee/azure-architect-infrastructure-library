targetScope = 'subscription'

type policyDefinitionReference = {
  policyDefinitionReferenceId: string
  policyDefinitionId: string
  // Parameters follow the ARM format: { paramName: { value: <val> } }
  parameters: object
}

@description('Azure region for the policy assignment identity (policy resources are subscription-scoped).')
param location string

@description('Environment tag.')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Name prefix used in all resource names.')
param namePrefix string

@description('Display name for the policy initiative and its assignment.')
param initiativeDisplayName string

@description('Description for the policy initiative.')
param initiativeDescription string

@description('Built-in or custom policy definitions to bundle into the initiative.')
param policyDefinitionReferences policyDefinitionReference[]

@description('Enforcement mode for the policy assignment. DoNotEnforce audits compliance without blocking deployments — recommended for dev.')
@allowed(['Default', 'DoNotEnforce'])
param enforcementMode string = 'DoNotEnforce'

@description('Resource IDs of scopes excluded from the policy assignment.')
param notScopes string[] = []

@description('Grant the assignment\'s system-assigned identity a role for DeployIfNotExists and Modify effect remediation.')
param enableRemediationIdentity bool = false

@description('Built-in role definition ID assigned to the policy identity when enableRemediationIdentity is true. Defaults to Contributor.')
param remediationRoleDefinitionId string = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

var tags = {
  environment: environment
  managedBy: 'bicep'
  pattern: 'policy-governance'
}

resource initiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: '${namePrefix}-initiative'
  properties: {
    displayName: initiativeDisplayName
    description: initiativeDescription
    policyType: 'Custom'
    metadata: {
      category: 'Governance'
      version: '1.0.0'
    }
    policyDefinitions: [for ref in policyDefinitionReferences: {
      policyDefinitionId: ref.policyDefinitionId
      policyDefinitionReferenceId: ref.policyDefinitionReferenceId
      parameters: ref.parameters
    }]
  }
}

// SystemAssigned identity is always provisioned so the assignment is remediation-ready
// without requiring a redeployment when DeployIfNotExists policies are added later.
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: '${namePrefix}-assignment'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: initiativeDisplayName
    description: initiativeDescription
    policyDefinitionId: initiative.id
    enforcementMode: enforcementMode
    notScopes: notScopes
    metadata: tags
  }
}

// Role assignment grants the policy identity permissions to remediate non-compliant resources.
// Only deploy when the initiative contains DeployIfNotExists or Modify effect policies.
resource remediationRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableRemediationIdentity) {
  name: guid(policyAssignment.id, remediationRoleDefinitionId, subscription().id)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', remediationRoleDefinitionId)
    principalId: policyAssignment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output initiativeId string = initiative.id
output initiativeName string = initiative.name
output assignmentId string = policyAssignment.id
output assignmentName string = policyAssignment.name
output assignmentPrincipalId string = policyAssignment.identity.principalId
