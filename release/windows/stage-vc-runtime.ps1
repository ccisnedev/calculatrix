[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$BuildDir = "",
    [string]$RedistDir = ""
)

$ErrorActionPreference = "Stop"

# Calculatrix.exe links the Visual C++ runtime as DLLs, and Flutter does not
# bundle them, so a machine without the VC++ redistributable fails at startup
# with STATUS_DLL_NOT_FOUND (0xC0000135). Shipping the three DLLs of the x64
# runtime next to the executable (app-local deployment) removes the dependency.
# The api-ms-win-crt-* imports resolve against the Universal CRT, which is part
# of Windows 10 and later.
$requiredDlls = @(
    "msvcp140.dll",
    "vcruntime140.dll",
    "vcruntime140_1.dll"
)

if ([string]::IsNullOrWhiteSpace($BuildDir)) {
    $BuildDir = Join-Path $RepoRoot "code\app\build\windows\x64\runner\Release"
}

if (-not (Test-Path $BuildDir)) {
    throw "Flutter Windows release bundle not found: $BuildDir"
}

function Find-RedistDir {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"

    if (-not (Test-Path $vswhere)) {
        throw "vswhere.exe not found. Install Visual Studio 2022 with the C++ build tools, or pass -RedistDir explicitly."
    }

    $installPath = & $vswhere -latest -products * `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -property installationPath

    if ([string]::IsNullOrWhiteSpace($installPath)) {
        throw "No Visual Studio installation with the x64 C++ toolset was found. Pass -RedistDir explicitly."
    }

    $redistRoot = Join-Path $installPath "VC\Redist\MSVC"

    if (-not (Test-Path $redistRoot)) {
        throw "VC redistributable payload not found under $redistRoot. Install the 'C++ Redistributable MSMs' / latest VC++ redistributable component."
    }

    # Version directories sort as text, so 14.9 would beat 14.44. Compare as versions.
    $versionDir = Get-ChildItem $redistRoot -Directory |
        Where-Object { $_.Name -as [version] } |
        Sort-Object { [version]$_.Name } -Descending |
        Select-Object -First 1

    if ($null -eq $versionDir) {
        throw "No versioned redistributable directory found under $redistRoot."
    }

    $crtDir = Get-ChildItem (Join-Path $versionDir.FullName "x64") -Directory -Filter "Microsoft.VC*.CRT" |
        Select-Object -First 1

    if ($null -eq $crtDir) {
        throw "No Microsoft.VC*.CRT directory found under $($versionDir.FullName)\x64."
    }

    return $crtDir.FullName
}

if ([string]::IsNullOrWhiteSpace($RedistDir)) {
    $RedistDir = Find-RedistDir
}

if (-not (Test-Path $RedistDir)) {
    throw "Redistributable directory not found: $RedistDir"
}

$resolvedBuildDir = (Resolve-Path $BuildDir).Path

foreach ($dll in $requiredDlls) {
    $source = Join-Path $RedistDir $dll

    if (-not (Test-Path $source)) {
        throw "Required runtime DLL not found in redistributable payload: $source"
    }

    Copy-Item -Path $source -Destination (Join-Path $resolvedBuildDir $dll) -Force
    Write-Output "STAGED=$dll"
}

Write-Output "REDIST_DIR=$RedistDir"
Write-Output "BUILD_DIR=$resolvedBuildDir"
