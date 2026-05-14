BeforeAll {
    $templateFile = Resolve-Path "$PSScriptRoot/../../key-vault/main.bicep"
    $paramFile    = Resolve-Path "$PSScriptRoot/../../key-vault/parameters/dev.bicepparam"
    $armFile      = "$PSScriptRoot/key-vault.compiled.json"

    az bicep build --file $templateFile --outfile $armFile 2>&1 | Out-Null
    $script:arm = Get-Content $armFile -Raw | ConvertFrom-Json
    $script:raw = Get-Content $templateFile -Raw
}

AfterAll {
    Remove-Item $armFile -ErrorAction SilentlyContinue
}

Describe 'key-vault — template structure' {
    It 'bicep template compiles without errors' {
        $result = az bicep build --file $templateFile 2>&1
        $result | Should -Not -Match 'Error'
    }

    It 'dev param file targets the correct template' {
        Get-Content $paramFile -Raw | Should -Match "using '../main\.bicep'"
    }

    It 'compiled template contains a Key Vault resource' {
        $vaults = $script:arm.resources | Where-Object { $_.type -eq 'Microsoft.KeyVault/vaults' }
        $vaults | Should -Not -BeNullOrEmpty
    }

    It 'compiled template contains role assignment resources' {
        $roles = $script:arm.resources | Where-Object { $_.type -eq 'Microsoft.Authorization/roleAssignments' }
        $roles | Should -Not -BeNullOrEmpty
    }

    It 'compiled template contains diagnostic settings' {
        $script:raw | Should -Match 'Microsoft.Insights/diagnosticSettings'
    }
}

Describe 'key-vault — security posture' {
    It 'RBAC authorization is enabled' {
        $script:raw | Should -Match 'enableRbacAuthorization.*true'
    }

    It 'soft-delete is enabled' {
        $script:raw | Should -Match 'enableSoftDelete.*true'
    }

    It 'legacy access policy flags are disabled' {
        $script:raw | Should -Match 'enabledForDeployment.*false'
        $script:raw | Should -Match 'enabledForDiskEncryption.*false'
        $script:raw | Should -Match 'enabledForTemplateDeployment.*false'
    }

    It 'Key Vault Secrets User role ID is used for kubelet assignment' {
        $script:raw | Should -Match '4633458b-17de-408a-b874-0445c86b69e6'
    }

    It 'Key Vault Administrator role ID is used for admin assignments' {
        $script:raw | Should -Match '00482a5a-887f-4fb3-b363-3b7fe8e74483'
    }

    It 'kubelet role assignment principal type is ServicePrincipal' {
        $script:raw | Should -Match "principalType: 'ServicePrincipal'"
    }
}

Describe 'key-vault — network access' {
    It 'network ACL defaultAction is wired from the networkAcls parameter' {
        $script:raw | Should -Match 'networkAcls\.defaultAction'
    }

    It 'network ACL bypass is wired from the networkAcls parameter' {
        $script:raw | Should -Match 'networkAcls\.bypass'
    }

    It 'virtual network rules loop over the provided subnet IDs' {
        $script:raw | Should -Match 'virtualNetworkSubnetIds'
    }
}

Describe 'key-vault — observability' {
    It 'diagnostic settings are conditional on logAnalyticsWorkspaceId' {
        $script:raw | Should -Match 'empty\(logAnalyticsWorkspaceId\)'
    }

    It 'diagnostic settings capture allLogs' {
        $script:raw | Should -Match 'allLogs'
    }
}

Describe 'key-vault — dev parameters' {
    It 'dev params disable purge protection' {
        Get-Content $paramFile -Raw | Should -Match 'enablePurgeProtection = false'
    }

    It 'dev params use minimum soft-delete retention' {
        Get-Content $paramFile -Raw | Should -Match 'softDeleteRetentionDays = 7'
    }

    It 'dev params allow all network traffic' {
        Get-Content $paramFile -Raw | Should -Match "defaultAction: 'Allow'"
    }
}
