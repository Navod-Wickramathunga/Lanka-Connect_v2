Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Running Flutter web (Chrome) against staging Firebase..."
flutter run -d chrome --dart-define=APP_ENV=staging
