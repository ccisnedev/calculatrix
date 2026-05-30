[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$BuildDir = "",
    [string]$OutputDir = "",
    [string]$PublicVersion = "",
    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($BuildDir)) {
    $BuildDir = Join-Path $RepoRoot "code\app\build\windows\x64\runner\Release"
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $RepoRoot "build\windows\installer"
}

$pubspecPath = Join-Path $RepoRoot "code\app\pubspec.yaml"
$issPath = Join-Path $RepoRoot "release\windows\Calculatrix.iss"
$licensePath = Join-Path $RepoRoot "LICENSE"
$iconPath = Join-Path $RepoRoot "code\app\windows\runner\resources\app_icon.ico"

foreach ($path in @($pubspecPath, $issPath, $licensePath, $iconPath)) {
    if (-not (Test-Path $path)) {
        throw "Required file not found: $path"
    }
}

if (-not (Test-Path $BuildDir)) {
    throw "Flutter Windows release bundle not found: $BuildDir"
}

if ([string]::IsNullOrWhiteSpace($PublicVersion)) {
    $versionLine = Select-String -Path $pubspecPath -Pattern '^version:\s*(.+)\s*$' | Select-Object -First 1

    if ($null -eq $versionLine) {
        throw "Could not locate version in $pubspecPath"
    }

    $pubspecVersion = $versionLine.Matches[0].Groups[1].Value.Trim()
    $PublicVersion = ($pubspecVersion -split '\+')[0]
}

if ([string]::IsNullOrWhiteSpace($PublicVersion)) {
    throw "Resolved public version is empty."
}

$resolvedBuildDir = (Resolve-Path $BuildDir).Path
$resolvedOutputDir = [System.IO.Path]::GetFullPath($OutputDir)

if ($ValidateOnly) {
    Write-Output "VALIDATION_OK=True"
    Write-Output "PUBLIC_VERSION=$PublicVersion"
    Write-Output "BUILD_DIR=$resolvedBuildDir"
    Write-Output "OUTPUT_DIR=$resolvedOutputDir"
    Write-Output "ISS_PATH=$issPath"
    exit 0
}

$compilerCommand = Get-Command ISCC.exe -ErrorAction SilentlyContinue

if ($null -ne $compilerCommand) {
    $compilerPath = $compilerCommand.Source
} else {
    $compilerPath = Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"
}

if (-not (Test-Path $compilerPath)) {
    throw "Inno Setup compiler not found. Install Inno Setup 6 or add ISCC.exe to PATH."
}

New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null

$arguments = @(
    "/DPublicVersion=$PublicVersion",
    "/DBuildDir=$resolvedBuildDir",
    "/DRepoRoot=$RepoRoot",
    "/DOutputDir=$resolvedOutputDir",
    $issPath
)

& $compilerPath @arguments

if ($LASTEXITCODE -ne 0) {
    throw "ISCC.exe failed with exit code $LASTEXITCODE"
}

$installerPath = Join-Path $resolvedOutputDir "Calculatrix-windows-x64-$PublicVersion-setup.exe"

if (-not (Test-Path $installerPath)) {
    throw "Expected installer not found after compilation: $installerPath"
}

Write-Output "INSTALLER_PATH=$installerPath"