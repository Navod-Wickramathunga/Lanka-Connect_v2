Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Assert-Command {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command '$Name' was not found in PATH."
  }
}

function Assert-File {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [string]$Hint = ""
  )

  if (-not (Test-Path -Path $Path -PathType Leaf)) {
    if ([string]::IsNullOrWhiteSpace($Hint)) {
      throw "Required file is missing: $Path"
    }
    throw "Required file is missing: $Path`n$Hint"
  }
}

Write-Host "Running Firebase preflight checks (outer root)..."

Assert-Command -Name "firebase"
Assert-Command -Name "flutter"
Assert-Command -Name "flutterfire"

$configureHint = @"
Run one of these from repository root:
  flutterfire configure --project=lankaconnect-app --platforms=android,ios,web --out=lib/firebase_options_staging.dart
  flutterfire configure --project=new-lanka-connect-app --platforms=android,ios,web --out=lib/firebase_options_production.dart
"@

$loginOutput = firebase login:list 2>&1
if ($LASTEXITCODE -ne 0) {
  throw "Failed to verify Firebase login status. Run 'firebase login'."
}

$loginText = ($loginOutput | Out-String).Trim()
if ($loginText -match "No authorized accounts") {
  throw "No authorized Firebase account detected. Run 'firebase login'."
}

Assert-File -Path "lib/firebase_options.dart" -Hint $configureHint
Assert-File -Path "android/app/google-services.json" -Hint $configureHint
Assert-File -Path "ios/Runner/GoogleService-Info.plist" -Hint $configureHint

Assert-File -Path "firestore.rules"
Assert-File -Path "firestore.indexes.json"
Assert-File -Path "storage.rules"
Assert-File -Path "functions/package.json"

Write-Host "Firebase preflight checks passed."
