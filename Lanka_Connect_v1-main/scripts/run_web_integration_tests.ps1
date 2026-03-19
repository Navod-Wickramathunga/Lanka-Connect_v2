<#
.SYNOPSIS
  Run integration tests on Chrome (web) with Firebase emulators.

.DESCRIPTION
  Uses flutter drive with the integration_test driver to run tests
  against Chrome. Requires ChromeDriver running on port 4444.

.PARAMETER TestFile
  The integration test file to run (default: all files matching *_test.dart).

.PARAMETER EmulatorHost
  The emulator host (default: localhost).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts/run_web_integration_tests.ps1
  powershell -ExecutionPolicy Bypass -File scripts/run_web_integration_tests.ps1 -TestFile notifications_query_test.dart
#>

param(
    [string]$TestFile = "",
    [string]$EmulatorHost = "localhost"
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "`n=== Lanka Connect: Web Integration Tests ===" -ForegroundColor Cyan
Write-Host "Emulator host: $EmulatorHost" -ForegroundColor Yellow

# Check if ChromeDriver is available
$chromeDriverRunning = $false
try {
    $response = Invoke-WebRequest -Uri "http://localhost:4444/status" -TimeoutSec 3 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) { $chromeDriverRunning = $true }
} catch { }

if (-not $chromeDriverRunning) {
    Write-Host "`nStarting ChromeDriver on port 4444..." -ForegroundColor Yellow
    Start-Process -FilePath "chromedriver" -ArgumentList "--port=4444" -NoNewWindow
    Start-Sleep -Seconds 2
}

$testFiles = @()
if ($TestFile -ne "") {
    $testFiles += "integration_test/$TestFile"
} else {
    $testFiles = Get-ChildItem -Path "integration_test" -Filter "*_test.dart" | ForEach-Object { "integration_test/$($_.Name)" }
}

$passed = 0
$failed = 0

foreach ($tf in $testFiles) {
    Write-Host "`nRunning: $tf" -ForegroundColor Cyan
    
    flutter drive `
        --driver=test_driver/integration_test.dart `
        --target=$tf `
        -d chrome `
        --dart-define=USE_FIREBASE_EMULATORS=true `
        --dart-define="FIREBASE_EMULATOR_HOST=$EmulatorHost"
    
    if ($LASTEXITCODE -eq 0) {
        $passed++
        Write-Host "PASSED: $tf" -ForegroundColor Green
    } else {
        $failed++
        Write-Host "FAILED: $tf" -ForegroundColor Red
    }
}

Write-Host "`n=== Results: $passed passed, $failed failed ===" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
