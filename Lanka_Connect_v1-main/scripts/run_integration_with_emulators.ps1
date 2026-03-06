param(
  [Parameter(Mandatory = $true)]
  [string]$DeviceId,
  [string]$TestPath = "integration_test\notifications_query_test.dart",
  [string]$EmulatorHost = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$args = @(
  "test",
  $TestPath,
  "-d",
  $DeviceId,
  "--flavor",
  "staging",
  "--dart-define=APP_ENV=emulator",
  "--dart-define=USE_FIREBASE_EMULATORS=true"
)

if (-not [string]::IsNullOrWhiteSpace($EmulatorHost)) {
  $args += "--dart-define=FIREBASE_EMULATOR_HOST=$EmulatorHost"
}

Write-Host "Running integration test '$TestPath' on device '$DeviceId'..."
flutter @args
