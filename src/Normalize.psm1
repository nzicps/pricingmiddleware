#requires -Version 7.0

<#
.SYNOPSIS
    Normalizes data from Terminal49 (tracking) and Freightos (pricing) into a
    single unified object shape for use by a route optimization engine.
#>

function ConvertTo-NormalizedShipment {
    <#
    .SYNOPSIS
        Takes a raw Terminal49 shipment response and flattens it into a simple,
        consistent object — so the route optimizer doesn't need to know about
        Terminal49's JSON:API structure.

    .PARAMETER T49Shipment
        The raw object returned by Get-T49Shipment.

    .EXAMPLE
        $raw = Get-T49Shipment -ShipmentId $id
        ConvertTo-NormalizedShipment -T49Shipment $raw
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$T49Shipment
    )

    $attrs = $T49Shipment.data.attributes

    $containers = @()
    if ($T49Shipment.included) {
        $containers = $T49Shipment.included |
            Where-Object { $_.type -eq 'container' } |
            ForEach-Object {
                [PSCustomObject]@{
                    container_number = $_.attributes.number
                    status           = $_.attributes.current_status
                    available        = $_.attributes.available_for_pickup
                    last_free_day    = $_.attributes.pickup_lfd
                    discharged_at    = $_.attributes.pod_discharged_at
                }
            }
    }

    [PSCustomObject]@{
        source              = 'terminal49'
        shipment_id          = $T49Shipment.data.id
        bill_of_lading       = $attrs.bill_of_lading_number
        carrier_scac         = $attrs.shipping_line_scac
        carrier_name         = $attrs.shipping_line_name
        port_of_lading       = $attrs.port_of_lading_locode
        port_of_discharge    = $attrs.port_of_discharge_locode
        vessel_name          = $attrs.pod_vessel_name
        voyage_number        = $attrs.pod_voyage_number
        planned_departure    = $attrs.pol_etd_at      # may be null - see notes below
        actual_departure     = $attrs.pol_atd_at
        planned_arrival      = $attrs.pod_eta_at      # may be null
        original_eta         = $attrs.pod_original_eta_at
        actual_arrival       = $attrs.pod_ata_at
        containers           = $containers
        retrieved_at         = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function ConvertTo-NormalizedPricing {
    <#
    .SYNOPSIS
        Flattens a raw Freightos pricing response into a simple, consistent object.

    .PARAMETER FreightosResponse
        The raw object returned by Get-FreightosEstimate or Get-FreightosBindingQuote.

    .PARAMETER Origin
        The origin used in the request (echoed back, since Freightos doesn't always include it).

    .PARAMETER Destination
        The destination used in the request.

    .EXAMPLE
        $raw = Get-FreightosEstimate -Origin 'CNSHA' -Destination 'USLGB' -LoadType container40
        ConvertTo-NormalizedPricing -FreightosResponse $raw -Origin 'CNSHA' -Destination 'USLGB'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$FreightosResponse,

        [Parameter(Mandatory)]
        [string]$Origin,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    $modeData = $FreightosResponse.response.estimatedFreightRates.mode

    # Freightos may return a single mode object or an array depending on numQuotes
    $modes = @($modeData)

    $results = foreach ($m in $modes) {
        [PSCustomObject]@{
            source           = 'freightos'
            origin           = $Origin
            destination      = $Destination
            mode             = $m.mode
            price_min        = [double]$m.price.min.moneyAmount.amount
            price_max        = [double]$m.price.max.moneyAmount.amount
            currency         = $m.price.min.moneyAmount.currency
            transit_days_min = [int]$m.transitTimes.min
            transit_days_max = [int]$m.transitTimes.max
            is_binding_quote = $false   # set true by caller if resultSet=cheapestEachMode was used
            retrieved_at     = (Get-Date).ToUniversalTime().ToString('o')
        }
    }

    return $results
}

function Merge-ShipmentAndPricing {
    <#
    .SYNOPSIS
        Combines a normalized shipment (tracking) record with normalized pricing
        records for the same port pair, into one object a route optimizer can consume.

    .PARAMETER Shipment
        Output of ConvertTo-NormalizedShipment.

    .PARAMETER Pricing
        Output of ConvertTo-NormalizedPricing (array).

    .EXAMPLE
        Merge-ShipmentAndPricing -Shipment $shipment -Pricing $pricingResults
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Shipment,

        [Parameter(Mandatory)]
        [object[]]$Pricing
    )

    [PSCustomObject]@{
        shipment = $Shipment
        pricing  = $Pricing
        route    = "$($Shipment.port_of_lading) -> $($Shipment.port_of_discharge)"
        merged_at = (Get-Date).ToUniversalTime().ToString('o')
    }
}

Export-ModuleMember -Function ConvertTo-NormalizedShipment, ConvertTo-NormalizedPricing, Merge-ShipmentAndPricing
