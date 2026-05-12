BeforeAll {
    $templateFile = Resolve-Path "$PSScriptRoot/../../hub-spoke-vnet/main.bicep"
    $paramFile    = Resolve-Path "$PSScriptRoot/../../hub-spoke-vnet/parameters/dev.bicepparam"
    $armFile      = "$PSScriptRoot/hub-spoke-vnet.compiled.json"

    # Compile once; all tests that inspect the ARM JSON reuse this file
    az bicep build --file $templateFile --outfile $armFile 2>&1 | Out-Null
    $script:arm = Get-Content $armFile -Raw | ConvertFrom-Json
}

AfterAll {
    Remove-Item $armFile -ErrorAction SilentlyContinue
}

Describe 'hub-spoke-vnet — template structure' {
    It 'bicep template compiles without errors' {
        $result = az bicep build --file $templateFile 2>&1
        $result | Should -Not -Match 'Error'
    }

    It 'dev param file targets the correct template' {
        Get-Content $paramFile -Raw | Should -Match "using '../main\.bicep'"
    }

    It 'compiled template contains a virtualNetworks resource' {
        $vnets = $script:arm.resources | Where-Object { $_.type -eq 'Microsoft.Network/virtualNetworks' }
        $vnets | Should -Not -BeNullOrEmpty
    }

    It 'compiled template contains a networkSecurityGroups resource for management' {
        $nsgs = $script:arm.resources | Where-Object { $_.type -eq 'Microsoft.Network/networkSecurityGroups' }
        $nsgs | Should -Not -BeNullOrEmpty
    }

    It 'compiled template contains virtualNetworkPeerings' {
        $peerings = $script:arm.resources | Where-Object { $_.type -eq 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings' }
        $peerings | Should -Not -BeNullOrEmpty
    }
}

Describe 'hub-spoke-vnet — hub subnet naming' {
    It 'hub VNet definition includes AzureFirewallSubnet' {
        $raw = Get-Content $templateFile -Raw
        $raw | Should -Match 'AzureFirewallSubnet'
    }

    It 'hub VNet definition includes AzureBastionSubnet' {
        $raw = Get-Content $templateFile -Raw
        $raw | Should -Match 'AzureBastionSubnet'
    }

    It 'hub VNet definition includes GatewaySubnet' {
        $raw = Get-Content $templateFile -Raw
        $raw | Should -Match 'GatewaySubnet'
    }
}

Describe 'hub-spoke-vnet — peering properties' {
    It 'template sets allowForwardedTraffic on hub-to-spoke peering' {
        $raw = Get-Content $templateFile -Raw
        $raw | Should -Match 'allowForwardedTraffic'
    }
}
