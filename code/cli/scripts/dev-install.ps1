# dev-install.ps1 — Build from source and install the Calculatrix CLI locally (Windows)
#
# Usage: .\scripts\dev-install.ps1
# Run from code/cli/

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$installDir = "$env:LOCALAPPDATA\calculatrix"
$binDir     = "$installDir\bin"

Write-Host "Building calculatrix CLI..."
dart pub get
dart compile exe bin/calculatrix_cli.dart -o bin/calculatrix.exe

Write-Host "Installing to $installDir..."

# Create directories
New-Item -ItemType Directory -Force "$binDir" | Out-Null

# Copy the binary
Copy-Item -Force bin/calculatrix.exe "$binDir\calculatrix.exe"

# Create the alias cx.cmd
# %~dp0 is the directory of this .cmd, so `cx` always runs the calculatrix.exe
# sitting next to it. A copy or symlink of the executable would go stale on
# the next install; this shim never does, since it never embeds a version.
$cxCmd = "$binDir\cx.cmd"
Set-Content -Path $cxCmd -Value @('@echo off', '"%~dp0calculatrix.exe" %*')

# Add to PATH if needed
$userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
if ($userPath -notlike "*$binDir*") {
    [System.Environment]::SetEnvironmentVariable('PATH', "$userPath;$binDir", 'User')
    Write-Host "Added $binDir to user PATH."
}

Write-Host "Done. Open a new terminal and run: cx"
