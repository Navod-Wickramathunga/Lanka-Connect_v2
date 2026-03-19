param(
  [string]$EmulatorHost = "localhost"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "Running Flutter web (Chrome) against Firebase emulators..."
flutter run -d chrome --dart-define=APP_ENV=emulator --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=$EmulatorHost
