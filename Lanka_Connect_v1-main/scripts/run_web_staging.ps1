param(
	[string]$BuildName = '',
	[string]$BuildNumber = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "Running Flutter web (Chrome) against staging Firebase..."
$flutterArgs = @(
	'run',
	'-d', 'chrome',
	'--dart-define=APP_ENV=staging'
)

if ($BuildName) {
	$flutterArgs += "--build-name=$BuildName"
}
if ($BuildNumber) {
	$flutterArgs += "--build-number=$BuildNumber"
}

if ($BuildName -or $BuildNumber) {
	Write-Host "Using build version: name='$BuildName' number='$BuildNumber'"
}

flutter @flutterArgs
