$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$nodeRoot = Join-Path $repoRoot ".tooling\node-v22.14.0-win-x64"
$node22 = Join-Path $nodeRoot "node.exe"
$npmBin = Join-Path $nodeRoot "node_modules\npm\bin"
$firebaseCli = Join-Path $env:APPDATA "npm\node_modules\firebase-tools\lib\bin\firebase.js"

if (-not (Test-Path $node22)) {
  throw "Node 22 runtime not found at $node22"
}

if (-not (Test-Path $firebaseCli)) {
  throw "firebase-tools CLI not found at $firebaseCli. Install it with: npm install -g firebase-tools"
}

if (Test-Path $npmBin) {
  $env:PATH = "$nodeRoot;$npmBin;$env:PATH"
} else {
  $env:PATH = "$nodeRoot;$env:PATH"
}

Write-Host "Using Node runtime:" $node22
Write-Host "PATH prefixed with:" $nodeRoot
& $node22 $firebaseCli @args
exit $LASTEXITCODE
