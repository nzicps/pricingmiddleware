#requires -Version 7.0
#requires -Module Pester

<#
.SYNOPSIS
    Unit tests for Normalize.psm1. Run with: Invoke-Pester ./tests/Normalize.Tests.ps1
    These tests use mock/sample data and do NOT call any live API or require API keys.
#>

BeforeAll {
    Import-Module "$PSScriptRoot/../src/Normalize.psm1" -Force
}

Describe 'ConvertTo-NormalizedShipment' {

    BeforeAll {
        # Sample shape taken from Terminal49's documented example response
        $script:sampleT49Response = [PSCustomObject]@{
            data = [PSCustomObject]@{
                id         = '02b1bd6f-407c-45bb-8645-06e7ee34e7e3'
                type       = 'shipment'
                attributes = [PSCustomObject]@{
                    bill_of_lading_number = 'MEDUF5399896'
                    shipping_line_scac    = 'MSCU'
                    shipping_line_name    = 'Mediterranean Shipping Company'
                    port_of_lading_locode = 'FRLEH'
                    port_of_discharge_locode = 'USNYC'
                    pod_vessel_name       = 'MSC ANISHA R.'
                    pod_voyage_number     = '421A'
                    pol_etd_at            = $null
                    pol_atd_at            = '2024-06-11T22:00:00Z'
                    pod_eta_at            = $null
                    pod_original_eta_at   = $null
                    pod_ata_at            = $null
                }
            }
            included = @(
                [PSCustomObject]@{
                    type       = 'container'
                    attributes = [PSCustomObject]@{
                        number               = 'CAIU7432986'
                        current_status       = 'available'
                        available_for_pickup = $true
                        pickup_lfd           = '2024-07-07T04:00:00Z'
                        pod_discharged_at    = '2024-06-22T04:00:00Z'
                    }
                }
            )
        }
    }

    It 'extracts the shipment id' {
        $result = ConvertTo-NormalizedShipment -T49Shipment $script:sampleT49Response
        $result.shipment_id | Should -Be '02b1bd6f-407c-45bb-8645-06e7ee34e7e3'
    }

    It 'extracts port of lading and discharge locodes' {
        $result = ConvertTo-NormalizedShipment -T49Shipment $script:sampleT49Response
        $result.port_of_lading    | Should -Be 'FRLEH'
        $result.port_of_discharge | Should -Be 'USNYC'
    }

    It 'handles a null planned_departure without throwing' {
        $result = ConvertTo-NormalizedShipment -T49Shipment $script:sampleT49Response
        $result.planned_departure | Should -BeNullOrEmpty
        $result.actual_departure  | Should -Be '2024-06-11T22:00:00Z'
    }

    It 'flattens included containers into a simple array' {
        $result = ConvertTo-NormalizedShipment -T49Shipment $script:sampleT49Response
        $result.containers.Count | Should -Be 1
        $result.containers[0].container_number | Should -Be 'CAIU7432986'
        $result.containers[0].status | Should -Be 'available'
    }

    It 'tags the source as terminal49' {
        $result = ConvertTo-NormalizedShipment -T49Shipment $script:sampleT49Response
        $result.source | Should -Be 'terminal49'
    }
}

Describe 'ConvertTo-NormalizedPricing' {

    BeforeAll {
        # Sample shape taken from Freightos' documented JSON example response
        $script:sampleFreightosResponse = [PSCustomObject]@{
            response = [PSCustomObject]@{
                estimatedFreightRates = [PSCustomObject]@{
                    numQuotes = '1'
                    mode      = [PSCustomObject]@{
                        mode  = 'FCL'
                        price = [PSCustomObject]@{
                            min = [PSCustomObject]@{ moneyAmount = [PSCustomObject]@{ amount = '3262'; currency = 'USD' } }
                            max = [PSCustomObject]@{ moneyAmount = [PSCustomObject]@{ amount = '3554'; currency = 'USD' } }
                        }
                        transitTimes = [PSCustomObject]@{ min = '17'; max = '21'; unit = 'days' }
                    }
                }
            }
        }
    }

    It 'extracts min and max price as numbers' {
        $result = ConvertTo-NormalizedPricing -FreightosResponse $script:sampleFreightosResponse `
            -Origin 'CNSHA' -Destination 'USLGB'
        $result[0].price_min | Should -Be 3262
        $result[0].price_max | Should -Be 3554
    }

    It 'extracts currency' {
        $result = ConvertTo-NormalizedPricing -FreightosResponse $script:sampleFreightosResponse `
            -Origin 'CNSHA' -Destination 'USLGB'
        $result[0].currency | Should -Be 'USD'
    }

    It 'extracts transit time range as integers' {
        $result = ConvertTo-NormalizedPricing -FreightosResponse $script:sampleFreightosResponse `
            -Origin 'CNSHA' -Destination 'USLGB'
        $result[0].transit_days_min | Should -Be 17
        $result[0].transit_days_max | Should -Be 21
    }

    It 'echoes back the origin and destination passed in' {
        $result = ConvertTo-NormalizedPricing -FreightosResponse $script:sampleFreightosResponse `
            -Origin 'CNSHA' -Destination 'USLGB'
        $result[0].origin      | Should -Be 'CNSHA'
        $result[0].destination | Should -Be 'USLGB'
    }
}

Describe 'Merge-ShipmentAndPricing' {

    It 'builds a route string from port of lading and discharge' {
        $shipment = [PSCustomObject]@{ port_of_lading = 'FRLEH'; port_of_discharge = 'USNYC' }
        $pricing  = @([PSCustomObject]@{ price_min = 100 })

        $result = Merge-ShipmentAndPricing -Shipment $shipment -Pricing $pricing
        $result.route | Should -Be 'FRLEH -> USNYC'
    }

    It 'keeps shipment and pricing as nested objects' {
        $shipment = [PSCustomObject]@{ port_of_lading = 'FRLEH'; port_of_discharge = 'USNYC' }
        $pricing  = @([PSCustomObject]@{ price_min = 100 })

        $result = Merge-ShipmentAndPricing -Shipment $shipment -Pricing $pricing
        $result.shipment.port_of_lading | Should -Be 'FRLEH'
        $result.pricing[0].price_min    | Should -Be 100
    }
}
