#requires -Version 7.0

<#
.SYNOPSIS
    Functions for calling the Freightos public shipping calculator API (freight pricing).

.NOTES
    No API key required for public marketplace rates.
    Rate limit: 100 calls/hour per IP (per Freightos docs).
    Per Freightos terms of service, any UI displaying this data must credit
    Freightos and link to https://ship.freightos.com.
#>

function Get-FreightosEstimate {
    <#
    .SYNOPSIS
        Gets a port-to-port or door-to-door freight price estimate (range, not binding).

    .PARAMETER Origin
        Origin: 5-letter UN/LOCODE seaport code, 3-letter airport code, or address string.

    .PARAMETER Destination
        Destination: 5-letter UN/LOCODE seaport code, 3-letter airport code, or address string.

    .PARAMETER LoadType
        container20, container40, container45, container40HC, container45HC, boxes, pallets, crate, envelope

    .PARAMETER Weight
        Weight in kg (only required for non-container load types).

    .PARAMETER Quantity
        Number of load units. Default 1.

    .PARAMETER Mode
        Restrict to a specific mode: air, LCL, FCL, LTL, FTL, express. Optional.

    .EXAMPLE
        Get-FreightosEstimate -Origin 'CNSHA' -Destination 'USLGB' -LoadType container40 -Quantity 2
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Origin,

        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter(Mandatory)]
        [ValidateSet('container20','container40','container45','container40HC','container45HC',
                      'boxes','pallets','crate','envelope')]
        [string]$LoadType,

        [double]$Weight,

        [int]$Quantity = 1,

        [ValidateSet('air','LCL','FCL','LTL','FTL','express')]
        [string]$Mode
    )

    $baseUrl = (Import-PowerShellDataFile -Path "$PSScriptRoot/Config.psd1").Freightos.BaseUrl

    $queryParams = [System.Collections.Specialized.NameValueCollection]::new()
    $queryParams.Add('origin', $Origin)
    $queryParams.Add('destination', $Destination)
    $queryParams.Add('loadtype', $LoadType)
    $queryParams.Add('quantity', $Quantity)
    $queryParams.Add('format', 'json')

    if ($Weight) { $queryParams.Add('weight', $Weight) }
    if ($Mode)   { $queryParams.Add('mode', $Mode) }

    $queryString = ($queryParams.AllKeys | ForEach-Object {
        "$_=$([System.Uri]::EscapeDataString($queryParams[$_]))"
    }) -join '&'

    $uri = "$baseUrl`?$queryString"

    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop
        return $response
    }
    catch {
        Write-Error "Freightos estimate request failed: $($_.Exception.Message)"
        throw
    }
}

function Get-FreightosBindingQuote {
    <#
    .SYNOPSIS
        Gets a binding quote (with quote ID and URL) instead of just a price range.
        Uses resultSet=cheapestEachMode per Freightos docs, which is required to
        receive a quote ID rather than an estimate range.

    .PARAMETER Origin
        Origin: 5-letter UN/LOCODE seaport code, 3-letter airport code, or address string.

    .PARAMETER Destination
        Destination: 5-letter UN/LOCODE seaport code, 3-letter airport code, or address string.

    .PARAMETER LoadType
        container20, container40, container45, container40HC, container45HC, boxes, pallets, crate, envelope

    .PARAMETER Quantity
        Number of load units. Default 1.

    .PARAMETER Mode
        Restrict to a specific mode: air, LCL, FCL, LTL, FTL, express. Optional but
        recommended when requesting a binding quote.

    .NOTES
        The simple GET method does not support future pickup dates or accessorials.
        For date-specific binding quotes, Freightos requires the XML POST flow with
        a full QuoteRequest XML document (see quoteRequest.xsd). This function covers
        the GET-based binding quote only.

    .EXAMPLE
        Get-FreightosBindingQuote -Origin 'CNSHA' -Destination 'USLGB' -LoadType container40 -Mode FCL
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Origin,

        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter(Mandatory)]
        [ValidateSet('container20','container40','container45','container40HC','container45HC',
                      'boxes','pallets','crate','envelope')]
        [string]$LoadType,

        [int]$Quantity = 1,

        [ValidateSet('air','LCL','FCL','LTL','FTL','express')]
        [string]$Mode
    )

    $baseUrl = (Import-PowerShellDataFile -Path "$PSScriptRoot/Config.psd1").Freightos.BaseUrl

    $queryParams = [System.Collections.Specialized.NameValueCollection]::new()
    $queryParams.Add('origin', $Origin)
    $queryParams.Add('destination', $Destination)
    $queryParams.Add('loadtype', $LoadType)
    $queryParams.Add('quantity', $Quantity)
    $queryParams.Add('format', 'json')
    $queryParams.Add('resultSet', 'cheapestEachMode')

    if ($Mode) { $queryParams.Add('mode', $Mode) }

    $queryString = ($queryParams.AllKeys | ForEach-Object {
        "$_=$([System.Uri]::EscapeDataString($queryParams[$_]))"
    }) -join '&'

    $uri = "$baseUrl`?$queryString"

    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop
        return $response
    }
    catch {
        Write-Error "Freightos binding quote request failed: $($_.Exception.Message)"
        throw
    }
}

Export-ModuleMember -Function Get-FreightosEstimate, Get-FreightosBindingQuote
