# dev-install.ps1: build from source and install the Calculatrix CLI locally (Windows)
#
# Usage: .\scripts\dev-install.ps1
# Run from code/cli/

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$installDir = "$env:LOCALAPPDATA\calculatrix"
$binDir     = "$installDir\bin"

Write-Host "Building cx CLI..."
dart pub get
dart compile exe bin/cx.dart -o bin/cx.exe

Write-Host "Installing to $installDir..."

# Create directories
New-Item -ItemType Directory -Force "$binDir" | Out-Null

# Copy the binary. No alias, no shim of any kind (issue #22): `cx.exe` is
# what the user runs directly. A `.cmd`/`.bat` shim runs through cmd.exe,
# which treats `^` as its own escape character while parsing the command
# line, before the shim body ever runs; that silently mangled
# `cx eval infix '2^0.5'` into `2 0.5` with no error. Running the compiled
# executable directly means `cx` receives exactly the argv its calling
# shell produced, in PowerShell and in cmd.exe alike.
Copy-Item -Force bin/cx.exe "$binDir\cx.exe"

# Remove a legacy cx.cmd shim and calculatrix.exe from a previous install,
# if either is still there.
$legacyCxCmd = "$binDir\cx.cmd"
if (Test-Path $legacyCxCmd) {
    Remove-Item -Force $legacyCxCmd
    Write-Host "Removed legacy $legacyCxCmd."
}
$legacyExe = "$binDir\calculatrix.exe"
if (Test-Path $legacyExe) {
    Remove-Item -Force $legacyExe
    Write-Host "Removed legacy $legacyExe."
}

# Add to PATH if needed
$userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
if ($userPath -notlike "*$binDir*") {
    [System.Environment]::SetEnvironmentVariable('PATH', "$userPath;$binDir", 'User')
    Write-Host "Added $binDir to user PATH."
}

Write-Host "Done. Open a new terminal and run: cx"
