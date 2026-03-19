param(
  [string]$EmulatorHost = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$args = @(
  "run",
  "--flavor",
  "staging",
  "--dart-define=APP_ENV=emulator",
  "--dart-define=USE_FIREBASE_EMULATORS=true"
)

if (-not [string]::IsNullOrWhiteSpace($EmulatorHost)) {
  $args += "--dart-define=FIREBASE_EMULATOR_HOST=$EmulatorHost"
}

Write-Host "Running Flutter app against Firebase emulators..."
flutter @args
