Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Running Flutter app against staging Firebase..."
flutter run --flavor staging --dart-define=APP_ENV=staging
