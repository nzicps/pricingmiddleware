#requires -Version 7.0

<#
.SYNOPSIS
    Demo entry point: pulls a Terminal49 shipment (tracking) and a Freightos
    price estimate (pricing) for the same port pair, normalizes both, and
    prints a single merged object.

.DESCRIPTION
    Run this after:
      1. Setting $env:T49_API_KEY with your free Terminal49 developer key
      2. Creating a tracking request (or already having a ShipmentId)

    Freightos requires no API key for public marketplace estimates.

.EXAMPLE
    pwsh ./Run-Demo.ps1 -ShipmentId '02b1bd6f-407c-45bb-8645-06e7ee34e7e3' `
        -OriginLocode 'CNSHA' -DestinationLocode 'USLGB'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ShipmentId,

    [Parameter(Mandatory)]
    [string]$OriginLocode,

    [Parameter(Mandatory)]
    [string]$DestinationLocode,

    [ValidateSet('container20','container40','container45','container40HC','container45HC')]
    [string]$ContainerType = 'container40'
)

$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/src/Terminal49.psm1" -Force
Import-Module "$PSScriptRoot/src/Freightos.psm1" -Force
Import-Module "$PSScriptRoot/src/Normalize.psm1" -Force

Write-Host "Fetching shipment from Terminal49..." -ForegroundColor Cyan
$rawShipment        = Get-T49Shipment -ShipmentId $ShipmentId
$normalizedShipment = ConvertTo-NormalizedShipment -T49Shipment $rawShipment

Write-Host "Fetching price estimate from Freightos..." -ForegroundColor Cyan
$rawPricing        = Get-FreightosEstimate -Origin $OriginLocode -Destination $DestinationLocode `
                        -LoadType $ContainerType -Quantity 1 -Mode FCL
$normalizedPricing = ConvertTo-NormalizedPricing -FreightosResponse $rawPricing `
                        -Origin $OriginLocode -Destination $DestinationLocode

Write-Host "Merging..." -ForegroundColor Cyan
$merged = Merge-ShipmentAndPricing -Shipment $normalizedShipment -Pricing $normalizedPricing

$merged | ConvertTo-Json -Depth 6
