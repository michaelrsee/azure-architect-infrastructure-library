BeforeAll {
    $templateFile = Resolve-Path "$PSScriptRoot/../../log-analytics-workspace/main.bicep"
    $paramFile    = Resolve-Path "$PSScriptRoot/../../log-analytics-workspace/parameters/dev.bicepparam"
    $armFile      = "$PSScriptRoot/log-analytics-workspace.compiled.json"

    az bicep build --file $templateFile --outfile $armFile 2>&1 | Out-Null
    $script:arm = Get-Content $armFile -Raw | ConvertFrom-Json
    $script:raw = Get-Content $templateFile -Raw
}

AfterAll {
    Remove-Item $armFile -ErrorAction SilentlyContinue
}

Describe 'log-analytics-workspace — template structure' {
    It 'bicep template compiles without errors' {
        $result = az bicep build --file $templateFile 2>&1
        $result | Should -Not -Match 'Error'
    }

    It 'dev param file targets the correct template' {
        Get-Content $paramFile -Raw | Should -Match "using '../main\.bicep'"
    }

    It 'compiled template contains a Log Analytics workspace resource' {
        $laws = $script:arm.resources | Where-Object { $_.type -eq 'Microsoft.OperationalInsights/workspaces' }
        $laws | Should -Not -BeNullOrEmpty
    }

    It 'compiled template contains an OMS solutions resource' {
        $solutions = $script:arm.resources | Where-Object { $_.type -eq 'Microsoft.OperationsManagement/solutions' }
        $solutions | Should -Not -BeNullOrEmpty
    }
}

Describe 'log-analytics-workspace — access control' {
    It 'resource-context permissions flag is wired to the workspace' {
        $script:raw | Should -Match 'enableLogAccessUsingOnlyResourcePermissions'
    }

    It 'public network access for ingestion is parameterised' {
        $script:raw | Should -Match 'publicNetworkAccessForIngestion'
    }

    It 'public network access for query is parameterised' {
        $script:raw | Should -Match 'publicNetworkAccessForQuery'
    }
}

Describe 'log-analytics-workspace — cost controls' {
    It 'daily quota cap is wired to the workspace' {
        $script:raw | Should -Match 'dailyQuotaGb'
    }

    It 'workspace capping block is present' {
        $script:raw | Should -Match 'workspaceCapping'
    }

    It 'capacityReservationLevel is only set for CapacityReservation SKU' {
        $script:raw | Should -Match "sku == 'CapacityReservation'"
    }
}

Describe 'log-analytics-workspace — OMS solutions' {
    It 'solution name follows the required <Solution>(<workspace>) convention' {
        $script:raw | Should -Match "'\$\{sol\.name\}\(\$\{workspace\.name\}\)'"
    }

    It 'solution is linked to the workspace resource ID' {
        $script:raw | Should -Match 'workspaceResourceId.*workspace\.id'
    }
}

Describe 'log-analytics-workspace — outputs' {
    It 'workspaceId is exported' {
        $script:raw | Should -Match 'output workspaceId'
    }

    It 'workspaceCustomerId is exported' {
        $script:raw | Should -Match 'output workspaceCustomerId'
    }
}

Describe 'log-analytics-workspace — dev parameters' {
    It 'dev params set a daily ingestion cap' {
        $paramContent = Get-Content $paramFile -Raw
        $paramContent | Should -Match 'dailyQuotaGb = \d+'
        $paramContent | Should -Not -Match 'dailyQuotaGb = -1'
    }

    It 'dev params include ContainerInsights solution' {
        Get-Content $paramFile -Raw | Should -Match 'ContainerInsights'
    }
}
