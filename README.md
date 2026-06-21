# Cross-Border Route Optimization Middleware (PowerShell)

Free-tier middleware that pulls container/shipment tracking data from
**Terminal49** and freight price estimates from **Freightos**, normalizes
both into one consistent schema, and merges them for use in route
optimization logic.

## What's included

| File | Purpose |
|---|---|
| `src/Config.psd1` | Non-secret config (base URLs). API keys are never stored here. |
| `src/Terminal49.psm1` | Calls Terminal49 API: create tracking requests, get shipments/containers. |
| `src/Freightos.psm1` | Calls Freightos public pricing API: estimates and binding quotes. |
| `src/Normalize.psm1` | Converts raw API responses into one unified shape; merges tracking + pricing. |
| `Run-Demo.ps1` | End-to-end script: pulls real data and prints a merged result. |
| `tests/Normalize.Tests.ps1` | Pester unit tests using mock data — no API key or internet required. |

## Prerequisites

- PowerShell 7+ (`pwsh`)
- A free Terminal49 developer key: https://app.terminal49.com/register
- Pester module for running tests: `Install-Module -Name Pester -Force -Scope CurrentUser`

## Setup

1. Clone the repo and `cd` into it.
2. Set your Terminal49 API key as an environment variable (do **not** hardcode it anywhere):

   ```powershell
   $env:T49_API_KEY = 'your-terminal49-key-here'
   ```

   Freightos public marketplace estimates require **no API key**.

## Running the unit tests (no API key needed)

```powershell
Install-Module -Name Pester -Force -Scope CurrentUser   # one-time
Invoke-Pester ./tests/Normalize.Tests.ps1 -Output Detailed
```

These tests validate the normalization/merging logic against sample data
shaped like real Terminal49 and Freightos responses, so you can verify the
logic works correctly before ever calling a live API.

## Running the live demo (needs T49_API_KEY + internet)

You need a Terminal49 **shipment ID**. Get one by first creating a tracking
request:

```powershell
Import-Module ./src/Terminal49.psm1 -Force
$tr = New-T49TrackingRequest -Number 'YOUR_BOL_OR_CONTAINER_NUMBER' `
        -NumberType bill_of_lading -ScacCode 'MSCU'
$tr.data.relationships.shipment.data.id   # this is your ShipmentId
```

Then run the full pipeline:

```powershell
./Run-Demo.ps1 -ShipmentId '<shipment-id-from-above>' `
    -OriginLocode 'CNSHA' -DestinationLocode 'USLGB' -ContainerType container40
```

This prints a merged JSON object combining live tracking milestones with a
live Freightos price estimate for that port pair.

## Known limitations (by design, see project notes)

- `planned_departure` (`pol_etd_at`) and `planned_arrival` (`pod_eta_at`) from
  Terminal49 can be `null` — carriers don't always publish forward ETDs/ETAs
  through the feed. Don't assume these are always populated.
- The Freightos **GET** estimate endpoint returns a price *range*, not a
  binding quote, and does not support specifying a future pickup date.
  `Get-FreightosBindingQuote` requests `resultSet=cheapestEachMode` to get a
  quote ID, but a date-specific binding quote requires the XML POST flow
  (not yet implemented here — see Freightos' `quoteRequest.xsd`).
- Freightos public API: 100 calls/hour per IP. Per Freightos' terms of
  service, any UI showing this pricing data must credit Freightos and link
  to https://ship.freightos.com.

## Pushing to GitHub

```bash
git init
git add .
git commit -m "Initial middleware: Terminal49 tracking + Freightos pricing"
git branch -M main
git remote add origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main
```

**Before your first commit**, double check `.env` or any file containing
`T49_API_KEY` is not staged — `git status` should not show it. The
`.gitignore` in this repo already excludes common secret file patterns, but
since the key is read from an environment variable rather than a file, there
is nothing secret to accidentally commit as long as you only ever set it
with `$env:T49_API_KEY = '...'` in your terminal session.
