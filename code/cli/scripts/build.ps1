# build.ps1: compile cx.exe and package it into the release archive layout
# (Windows).
#
# Usage: .\scripts\build.ps1
# Run from code/cli/. Used by .github/workflows/cli-release.yml and usable
# locally to reproduce a release build without pushing anything.
#
# Produces build\bin\cx.exe and cx-windows-x64.zip at the current directory,
# with cx.exe directly under a top-level bin\ folder in the archive. That
# layout is required by modular_cli_sdk's WindowsPlatformOps: `expandArchive`
# extracts straight into the install directory, and `runPostInstall` /
# `scheduleDeletion` look for `<installDir>\bin\<binaryName>`.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "Fetching dependencies..."
dart pub get

Write-Host "Compiling cx.exe..."
New-Item -ItemType Directory -Force -Path build\bin | Out-Null
dart compile exe bin\cx.dart -o build\bin\cx.exe

$asset = 'cx-windows-x64.zip'
Write-Host "Packaging $asset..."
if (Test-Path $asset) {
    Remove-Item -Force $asset
}
Compress-Archive -Path build\bin -DestinationPath $asset

Write-Host "Done: $asset"
