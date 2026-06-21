#requires -Version 7.0

<#
.SYNOPSIS
    Functions for calling the Terminal49 API (container/shipment tracking).

.NOTES
    Requires environment variable T49_API_KEY to be set before use.
    Get a free developer key at: https://app.terminal49.com/register
#>

function Get-T49ApiKey {
    [CmdletBinding()]
    param()

    $key = $env:T49_API_KEY
    if ([string]::IsNullOrWhiteSpace($key)) {
        throw "Environment variable T49_API_KEY is not set. Run: `$env:T49_API_KEY = 'your-key-here'"
    }
    return $key
}

function New-T49TrackingRequest {
    <#
    .SYNOPSIS
        Creates a new tracking request in Terminal49 using a container, BOL, or booking number.

    .PARAMETER Number
        The container number, bill of lading number, or booking number to track.

    .PARAMETER NumberType
        One of: container, bill_of_lading, booking_number

    .PARAMETER ScacCode
        Carrier SCAC code (e.g. MAEU for Maersk, MSCU for MSC). Required by the API.

    .EXAMPLE
        New-T49TrackingRequest -Number 'MEDUF5399896' -NumberType bill_of_lading -ScacCode 'MSCU'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Number,

        [Parameter(Mandatory)]
        [ValidateSet('container', 'bill_of_lading', 'booking_number')]
        [string]$NumberType,

        [Parameter(Mandatory)]
        [string]$ScacCode
    )

    $apiKey  = Get-T49ApiKey
    $baseUrl = (Import-PowerShellDataFile -Path "$PSScriptRoot/Config.psd1").Terminal49.BaseUrl

    $body = @{
        data = @{
            type       = 'tracking_request'
            attributes = @{
                request_number      = $Number
                request_type        = $NumberType
                scac                = $ScacCode
            }
        }
    } | ConvertTo-Json -Depth 5

    $headers = @{
        'Authorization' = "Token $apiKey"
        'Content-Type'  = 'application/json'
    }

    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/tracking_requests" `
            -Method Post -Headers $headers -Body $body -ErrorAction Stop
        return $response
    }
    catch {
        Write-Error "Terminal49 tracking request failed: $($_.Exception.Message)"
        throw
    }
}

function Get-T49Shipment {
    <#
    .SYNOPSIS
        Retrieves a shipment record by its Terminal49 shipment ID, including containers.

    .PARAMETER ShipmentId
        The Terminal49 UUID for the shipment (returned from a tracking request).

    .EXAMPLE
        Get-T49Shipment -ShipmentId '02b1bd6f-407c-45bb-8645-06e7ee34e7e3'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ShipmentId
    )

    $apiKey  = Get-T49ApiKey
    $baseUrl = (Import-PowerShellDataFile -Path "$PSScriptRoot/Config.psd1").Terminal49.BaseUrl

    $headers = @{ 'Authorization' = "Token $apiKey" }

    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/shipments/$ShipmentId`?include=containers" `
            -Method Get -Headers $headers -ErrorAction Stop
        return $response
    }
    catch {
        Write-Error "Terminal49 Get-Shipment failed: $($_.Exception.Message)"
        throw
    }
}

function Get-T49ContainerList {
    <#
    .SYNOPSIS
        Lists all containers currently tracked on your Terminal49 account.

    .EXAMPLE
        Get-T49ContainerList
    #>
    [CmdletBinding()]
    param()

    $apiKey  = Get-T49ApiKey
    $baseUrl = (Import-PowerShellDataFile -Path "$PSScriptRoot/Config.psd1").Terminal49.BaseUrl

    $headers = @{ 'Authorization' = "Token $apiKey" }

    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/containers" `
            -Method Get -Headers $headers -ErrorAction Stop
        return $response
    }
    catch {
        Write-Error "Terminal49 Get-ContainerList failed: $($_.Exception.Message)"
        throw
    }
}

Export-ModuleMember -Function New-T49TrackingRequest, Get-T49Shipment, Get-T49ContainerList, Get-T49ApiKey
