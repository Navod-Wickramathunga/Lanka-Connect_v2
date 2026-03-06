param(
    [ValidateSet('staging', 'production')]
    [string]$ProjectAlias = 'production',
    [switch]$SkipFunctions,
    [switch]$SkipHosting
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Command {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command '$Name' was not found in PATH."
  }
}

Assert-Command -Name "firebase"

Write-Host "Deploying Firebase stack to alias: $ProjectAlias" -ForegroundColor Cyan

if (-not $SkipFunctions) {
  if (-not (Test-Path "functions/node_modules")) {
    Write-Host "Installing Functions dependencies..." -ForegroundColor Yellow
    Push-Location functions
    npm.cmd install
    Pop-Location
  }

  Write-Host "Building Functions..." -ForegroundColor Yellow
  Push-Location functions
  npm.cmd run build
  Pop-Location
}

$deployTargets = @(
  "firestore:rules",
  "firestore:indexes",
  "storage"
)

if (-not $SkipFunctions) {
  $deployTargets += "functions"
}

if (-not $SkipHosting) {
  $deployTargets += "hosting"
}

$onlyArg = [string]::Join(",", $deployTargets)

Write-Host "firebase deploy --project $ProjectAlias --only $onlyArg" -ForegroundColor Yellow
if (-not $env:FUNCTIONS_DISCOVERY_TIMEOUT) {
  $env:FUNCTIONS_DISCOVERY_TIMEOUT = "60000"
  Write-Host "Using FUNCTIONS_DISCOVERY_TIMEOUT=$($env:FUNCTIONS_DISCOVERY_TIMEOUT)" -ForegroundColor DarkGray
}
firebase deploy --project $ProjectAlias --only $onlyArg

if ($LASTEXITCODE -ne 0) {
  throw "Firebase deploy failed for alias '$ProjectAlias'."
}

Write-Host "Firebase deploy completed for alias '$ProjectAlias'." -ForegroundColor Green
