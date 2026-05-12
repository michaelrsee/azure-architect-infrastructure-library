BeforeAll {
    $templateFile = Resolve-Path "$PSScriptRoot/../../policy-governance/main.bicep"
    $paramFile    = Resolve-Path "$PSScriptRoot/../../policy-governance/parameters/dev.bicepparam"
    $armFile      = "$PSScriptRoot/policy-governance.compiled.json"

    az bicep build --file $templateFile --outfile $armFile 2>&1 | Out-Null
    $script:arm = Get-Content $armFile -Raw | ConvertFrom-Json
    $script:raw = Get-Content $templateFile -Raw
}

AfterAll {
    Remove-Item $armFile -ErrorAction SilentlyContinue
}

Describe 'policy-governance — template structure' {
    It 'bicep template compiles without errors' {
        $result = az bicep build --file $templateFile 2>&1
        $result | Should -Not -Match 'Error'
    }

    It 'dev param file targets the correct template' {
        Get-Content $paramFile -Raw | Should -Match "using '../main\.bicep'"
    }

    It 'targetScope is subscription' {
        $script:raw | Should -Match "targetScope = 'subscription'"
    }

    It 'compiled template contains a policySetDefinitions resource' {
        $initiatives = $script:arm.resources | Where-Object { $_.type -eq 'Microsoft.Authorization/policySetDefinitions' }
        $initiatives | Should -Not -BeNullOrEmpty
    }

    It 'compiled template contains a policyAssignments resource' {
        $assignments = $script:arm.resources | Where-Object { $_.type -eq 'Microsoft.Authorization/policyAssignments' }
        $assignments | Should -Not -BeNullOrEmpty
    }

    It 'compiled template contains a roleAssignments resource' {
        $roles = $script:arm.resources | Where-Object { $_.type -eq 'Microsoft.Authorization/roleAssignments' }
        $roles | Should -Not -BeNullOrEmpty
    }
}

Describe 'policy-governance — assignment identity' {
    It 'policy assignment uses SystemAssigned identity' {
        $script:raw | Should -Match "type: 'SystemAssigned'"
    }

    It 'role assignment is conditional on enableRemediationIdentity' {
        $script:raw | Should -Match 'if \(enableRemediationIdentity\)'
    }

    It 'role assignment principal ID comes from the policy assignment identity' {
        $script:raw | Should -Match 'policyAssignment\.identity\.principalId'
    }
}

Describe 'policy-governance — enforcement and scope' {
    It 'enforcementMode parameter is present' {
        $script:raw | Should -Match 'enforcementMode'
    }

    It 'DoNotEnforce is an allowed value' {
        $script:raw | Should -Match 'DoNotEnforce'
    }

    It 'notScopes parameter is wired to the assignment' {
        $script:raw | Should -Match 'notScopes'
    }
}

Describe 'policy-governance — dev parameters' {
    It 'dev params set enforcementMode to DoNotEnforce' {
        Get-Content $paramFile -Raw | Should -Match "enforcementMode = 'DoNotEnforce'"
    }

    It 'dev params include at least one policy definition reference' {
        $paramContent = Get-Content $paramFile -Raw
        $paramContent | Should -Match 'policyDefinitionId'
    }

    It 'dev params disable remediation identity' {
        Get-Content $paramFile -Raw | Should -Match 'enableRemediationIdentity = false'
    }
}
