BeforeAll {
    $templateFile = Resolve-Path "$PSScriptRoot/../../aks-cluster/main.bicep"
    $paramFile    = Resolve-Path "$PSScriptRoot/../../aks-cluster/parameters/dev.bicepparam"
    $armFile      = "$PSScriptRoot/aks-cluster.compiled.json"

    az bicep build --file $templateFile --outfile $armFile 2>&1 | Out-Null
    $script:arm = Get-Content $armFile -Raw | ConvertFrom-Json
    $script:raw = Get-Content $templateFile -Raw
}

AfterAll {
    Remove-Item $armFile -ErrorAction SilentlyContinue
}

Describe 'aks-cluster — template structure' {
    It 'bicep template compiles without errors' {
        $result = az bicep build --file $templateFile 2>&1
        $result | Should -Not -Match 'Error'
    }

    It 'dev param file targets the correct template' {
        Get-Content $paramFile -Raw | Should -Match "using '../main\.bicep'"
    }

    It 'compiled template contains a managedClusters resource' {
        $clusters = $script:arm.resources | Where-Object { $_.type -eq 'Microsoft.ContainerService/managedClusters' }
        $clusters | Should -Not -BeNullOrEmpty
    }

    It 'compiled template contains a Log Analytics workspace' {
        $laws = $script:arm.resources | Where-Object { $_.type -eq 'Microsoft.OperationalInsights/workspaces' }
        $laws | Should -Not -BeNullOrEmpty
    }

    It 'compiled template contains a user-assigned managed identity' {
        $ids = $script:arm.resources | Where-Object { $_.type -eq 'Microsoft.ManagedIdentity/userAssignedIdentities' }
        $ids | Should -Not -BeNullOrEmpty
    }
}

Describe 'aks-cluster — security posture' {
    It 'RBAC is enabled' {
        $script:raw | Should -Match 'enableRBAC.*true'
    }

    It 'AAD managed integration is enabled' {
        $script:raw | Should -Match 'managed.*true'
    }

    It 'Azure RBAC is enabled on AAD profile' {
        $script:raw | Should -Match 'enableAzureRBAC.*true'
    }

    It 'OIDC issuer profile is enabled' {
        $script:raw | Should -Match 'oidcIssuerProfile'
    }

    It 'workload identity is enabled' {
        $script:raw | Should -Match 'workloadIdentity'
    }

    It 'Azure Policy addon is present' {
        $script:raw | Should -Match 'azurepolicy'
    }
}

Describe 'aks-cluster — observability' {
    It 'omsagent addon is configured' {
        $script:raw | Should -Match 'omsagent'
    }

    It 'Log Analytics workspace is wired to omsagent' {
        $script:raw | Should -Match 'logAnalyticsWorkspaceResourceID'
    }
}

Describe 'aks-cluster — network' {
    It 'standard load balancer SKU is set' {
        $script:raw | Should -Match 'standard'
    }

    It 'network plugin switches on subnetId' {
        $script:raw | Should -Match "empty\(subnetId\)"
    }
}
