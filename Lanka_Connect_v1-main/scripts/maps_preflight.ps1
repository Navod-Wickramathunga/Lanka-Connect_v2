Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RegexValue {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [Parameter(Mandatory = $true)][string]$Pattern
  )

  $match = [regex]::Match($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
  if (-not $match.Success) { return $null }
  return $match.Groups[1].Value
}

function Mask-Key {
  param([string]$Key)
  if ([string]::IsNullOrWhiteSpace($Key)) { return "<missing>" }
  if ($Key.Length -le 8) { return $Key }
  return "{0}...{1}" -f $Key.Substring(0, 8), $Key.Substring($Key.Length - 4)
}

$repoRoot = Split-Path -Parent $PSScriptRoot

$androidGradlePath = Join-Path $repoRoot "android\\app\\build.gradle.kts"
$androidManifestPath = Join-Path $repoRoot "android\\app\\src\\main\\AndroidManifest.xml"
$iosAppDelegatePath = Join-Path $repoRoot "ios\\Runner\\AppDelegate.swift"
$iosProjectPath = Join-Path $repoRoot "ios\\Runner.xcodeproj\\project.pbxproj"
$webIndexPath = Join-Path $repoRoot "web\\index.html"

$requiredFiles = @(
  $androidGradlePath,
  $androidManifestPath,
  $iosAppDelegatePath,
  $iosProjectPath,
  $webIndexPath
)

foreach ($file in $requiredFiles) {
  if (-not (Test-Path -Path $file)) {
    throw "Required file not found: $file"
  }
}

$androidGradle = Get-Content -Path $androidGradlePath -Raw
$androidManifest = Get-Content -Path $androidManifestPath -Raw
$iosAppDelegate = Get-Content -Path $iosAppDelegatePath -Raw
$iosProject = Get-Content -Path $iosProjectPath -Raw
$webIndex = Get-Content -Path $webIndexPath -Raw

$androidAppId = Get-RegexValue -Text $androidGradle -Pattern 'applicationId\s*=\s*"([^"]+)"'
$androidStagingSuffix = Get-RegexValue -Text $androidGradle -Pattern 'applicationIdSuffix\s*=\s*"([^"]+)"'
if ([string]::IsNullOrWhiteSpace($androidAppId)) {
  throw "Could not parse Android applicationId from $androidGradlePath"
}

$androidPackages = @($androidAppId)
if (-not [string]::IsNullOrWhiteSpace($androidStagingSuffix)) {
  $androidPackages += "$androidAppId$androidStagingSuffix"
}

$bundleIdMatches = [regex]::Matches($iosProject, 'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);')
$bundleIds = @()
foreach ($m in $bundleIdMatches) {
  $bundleId = $m.Groups[1].Value.Trim()
  if ($bundleId -notmatch 'RunnerTests' -and $bundleIds -notcontains $bundleId) {
    $bundleIds += $bundleId
  }
}
if ($bundleIds.Count -eq 0) {
  throw "Could not parse iOS bundle IDs from $iosProjectPath"
}

$androidMapKey = Get-RegexValue -Text $androidManifest -Pattern 'com\.google\.android\.geo\.API_KEY"[\s\S]*?android:value="([^"]+)"'
$iosMapKey = Get-RegexValue -Text $iosAppDelegate -Pattern 'GMSServices\.provideAPIKey\("([^"]+)"\)'
$webMapKey = Get-RegexValue -Text $webIndex -Pattern 'maps\.googleapis\.com/maps/api/js\?key=([^"&]+)'

$hasAndroidInjection = -not [string]::IsNullOrWhiteSpace($androidMapKey)
$hasIosInjection = -not [string]::IsNullOrWhiteSpace($iosMapKey)
$hasWebInjection = -not [string]::IsNullOrWhiteSpace($webMapKey)

Write-Host ""
Write-Host "Google Maps preflight summary" -ForegroundColor Cyan
Write-Host "--------------------------------"
Write-Host "Android package IDs:"
$androidPackages | ForEach-Object { Write-Host "  - $_" }
Write-Host "iOS bundle IDs:"
$bundleIds | ForEach-Object { Write-Host "  - $_" }
Write-Host ""
Write-Host "Detected Maps key injection points:"
Write-Host ("  - Android manifest key: {0}" -f (Mask-Key $androidMapKey))
Write-Host ("  - iOS AppDelegate key: {0}" -f (Mask-Key $iosMapKey))
Write-Host ("  - Web index key: {0}" -f (Mask-Key $webMapKey))
Write-Host ""
Write-Host "Required Cloud Console setup:"
Write-Host "  - Billing enabled for the key-owning project"
Write-Host "  - APIs enabled: Maps SDK for Android, Maps JavaScript API (and Maps SDK for iOS if iOS is used)"
Write-Host ""
Write-Host "Apply these key restrictions:"
Write-Host "  Android key:"
Write-Host "    - Application restriction: Android apps"
Write-Host "    - Packages:"
$androidPackages | ForEach-Object { Write-Host "      - $_" }
Write-Host "    - SHA-1 fingerprints: debug and release"
Write-Host "  Web key:"
Write-Host "    - Application restriction: HTTP referrers"
Write-Host "    - Referrers:"
Write-Host "      - http://localhost/*"
Write-Host "      - http://127.0.0.1/*"
Write-Host "      - https://lankaconnect-app.web.app/*"
Write-Host "      - https://new-lanka-connect-app.web.app/*"
Write-Host "  iOS key:"
Write-Host "    - Application restriction: iOS apps"
foreach ($bundleId in $bundleIds) {
  Write-Host "      - Bundle ID: $bundleId"
}
Write-Host ""
Write-Host "SHA-1 helper commands:"
Write-Host '  Debug:  keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android | Select-String "SHA1:"'
Write-Host '  Release: keytool -list -v -alias <keyAlias> -keystore <storeFile> -storepass <storePassword> -keypass <keyPassword> | Select-String "SHA1:"'

if (-not ($hasAndroidInjection -and $hasIosInjection -and $hasWebInjection)) {
  throw "One or more Maps key injection points are missing in repo files. See summary above."
}

Write-Host ""
Write-Host "Maps preflight completed." -ForegroundColor Green
