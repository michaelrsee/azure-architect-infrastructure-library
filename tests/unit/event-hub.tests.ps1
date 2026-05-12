BeforeAll {
    $templateFile = Resolve-Path "$PSScriptRoot/../../event-hub/main.bicep"
    $paramFile    = Resolve-Path "$PSScriptRoot/../../event-hub/parameters/dev.bicepparam"
    $armFile      = "$PSScriptRoot/event-hub.compiled.json"

    az bicep build --file $templateFile --outfile $armFile 2>&1 | Out-Null
    $script:arm = Get-Content $armFile -Raw | ConvertFrom-Json
    $script:raw = Get-Content $templateFile -Raw
}

AfterAll {
    Remove-Item $armFile -ErrorAction SilentlyContinue
}

Describe 'event-hub — template structure' {
    It 'bicep template compiles without errors' {
        $result = az bicep build --file $templateFile 2>&1
        $result | Should -Not -Match 'Error'
    }

    It 'dev param file targets the correct template' {
        Get-Content $paramFile -Raw | Should -Match "using '../main\.bicep'"
    }

    It 'compiled template contains an Event Hubs namespace' {
        $ns = $script:arm.resources | Where-Object { $_.type -eq 'Microsoft.EventHub/namespaces' }
        $ns | Should -Not -BeNullOrEmpty
    }

    It 'compiled template contains event hub instances' {
        $hubs = $script:arm.resources | Where-Object { $_.type -eq 'Microsoft.EventHub/namespaces/eventhubs' }
        $hubs | Should -Not -BeNullOrEmpty
    }

    It 'compiled template contains consumer groups' {
        $cgs = $script:arm.resources | Where-Object { $_.type -eq 'Microsoft.EventHub/namespaces/eventhubs/consumergroups' }
        $cgs | Should -Not -BeNullOrEmpty
    }
}

Describe 'event-hub — security posture' {
    It 'minimum TLS version is set to 1.2' {
        $script:raw | Should -Match "minimumTlsVersion.*1\.2"
    }

    It 'disableLocalAuth parameter is present' {
        $script:raw | Should -Match 'disableLocalAuth'
    }
}

Describe 'event-hub — observability' {
    It 'diagnostic settings resource is present' {
        $script:raw | Should -Match 'Microsoft.Insights/diagnosticSettings'
    }

    It 'diagnostic settings are conditional on logAnalyticsWorkspaceId' {
        $script:raw | Should -Match 'empty\(logAnalyticsWorkspaceId\)'
    }

    It 'diagnostic settings capture allLogs' {
        $script:raw | Should -Match 'allLogs'
    }
}

Describe 'event-hub — namespace configuration' {
    It 'auto-inflate is gated to Standard SKU' {
        $script:raw | Should -Match "sku == 'Standard'"
    }

    It 'consumer groups use flatten to resolve nested loop' {
        $script:raw | Should -Match 'flatten\('
    }
}
