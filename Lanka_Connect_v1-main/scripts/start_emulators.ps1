Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "Starting Firebase emulators (auth, firestore, storage, ui)..."
firebase emulators:start --only "auth,firestore,storage,ui"
