Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Running Flutter app against production Firebase..."
flutter run --flavor production --dart-define=APP_ENV=production
