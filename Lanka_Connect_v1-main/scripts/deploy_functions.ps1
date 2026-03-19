<#
.SYNOPSIS
  Deploy Cloud Functions to Firebase (requires Blaze plan).
  
.DESCRIPTION
  Builds TypeScript and deploys all Cloud Functions.
  Prerequisites:
    - Firebase CLI installed: npm install -g firebase-tools
    - Logged in: firebase login
    - Project on Blaze (pay-as-you-go) plan
    - functions/node_modules installed: cd functions && npm install

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts/deploy_functions.ps1
#>

param(
    [ValidateSet('staging', 'production', 'default')]
    [string]$ProjectAlias = 'production'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "`n=== Lanka Connect: Cloud Functions Deployment ===" -ForegroundColor Cyan
Write-Host "Target Firebase alias: $ProjectAlias" -ForegroundColor Cyan

# Verify Firebase CLI
try {
    $fbVersion = & firebase --version 2>&1
    Write-Host "Firebase CLI: $fbVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Firebase CLI not found. Install with: npm install -g firebase-tools" -ForegroundColor Red
    exit 1
}

# Verify node_modules
if (-not (Test-Path "functions/node_modules")) {
    Write-Host "Installing Functions dependencies..." -ForegroundColor Yellow
    Push-Location functions
    npm.cmd install
    Pop-Location
}

# Build TypeScript
Write-Host "`nBuilding TypeScript..." -ForegroundColor Yellow
Push-Location functions
npm.cmd run build
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: TypeScript build failed." -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location
Write-Host "Build successful." -ForegroundColor Green

# Deploy
Write-Host "`nDeploying Cloud Functions..." -ForegroundColor Yellow
if (-not $env:FUNCTIONS_DISCOVERY_TIMEOUT) {
    $env:FUNCTIONS_DISCOVERY_TIMEOUT = "60000"
    Write-Host "Using FUNCTIONS_DISCOVERY_TIMEOUT=$($env:FUNCTIONS_DISCOVERY_TIMEOUT)" -ForegroundColor DarkGray
}
firebase deploy --project $ProjectAlias --only functions

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n=== Deployment successful! ===" -ForegroundColor Green
    Write-Host "Deployed functions:"
    Write-Host "  - setServicePendingOnCreate (Firestore trigger)"
    Write-Host "  - notifyOnServiceApproval (Firestore trigger)"
    Write-Host "  - updateProviderRatingOnReviewCreate (Firestore trigger)"
    Write-Host "  - seedDemoData (callable)"
} else {
    Write-Host "`n=== Deployment failed ===" -ForegroundColor Red
    Write-Host "Common issues:"
    Write-Host "  1. Project not on Blaze plan (upgrade at https://console.firebase.google.com)"
    Write-Host "  2. Not logged in (run: firebase login)"
    Write-Host "  3. Wrong project (run: firebase use <project-id>)"
    exit 1
}
