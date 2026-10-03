# install.ps1: downloads and installs the latest Calculatrix CLI release
# (Windows).
#
# Usage:
#   irm https://calculatrix.ccisne.dev/install.ps1 | iex
#
# This file is served from the site's web build (see
# .github/workflows/pages-release.yml, which copies it there) and also lives
# here as its source of truth.
#
# Modeled on ccisnedev/inquiry's code/site/install.ps1, adapted for
# calculatrix (runbook docs/runbook-cli-stage-0.md, "Publishing (dogfood)"):
#   - this repository also publishes app releases tagged vX.Y.Z, so this
#     script lists releases and picks the newest cli-v* one instead of
#     calling GET /releases/latest, which would resolve to whichever kind of
#     release happens to be newest (constraint 3 in the runbook, D31);
#   - no `iq.cmd` (or any other) alias or shim is created: `cx` is the only
#     executable, with no alias of any kind (issue #22, D40);
#   - there is no host/skill deployment step: calculatrix has none;
#   - the collision check below is calculatrix-specific: inquiry's script
#     has none.
#
# What it does:
#   1. Detects Windows x64
#   2. Warns if `cx` already resolves to something this installer did not
#      put there
#   3. Lists releases and picks the newest cli-v* tag
#   4. Downloads the matching cx-windows-x64.zip from GitHub Releases
#   5. Extracts to $env:LOCALAPPDATA\calculatrix\ (bin\cx.exe)
#   6. Adds calculatrix\bin\ to the user PATH
#   7. Verifies with `cx version`

$ErrorActionPreference = 'Stop'

$repo = 'ccisnedev/calculatrix'
$installDir = Join-Path $env:LOCALAPPDATA 'calculatrix'
$binDir = Join-Path $installDir 'bin'
$exePath = Join-Path $binDir 'cx.exe'

# --- Platform check --------------------------------------------------------

if ($env:OS -ne 'Windows_NT') {
    Write-Error 'The Calculatrix CLI Windows installer requires Windows.'
    exit 1
}

if ([System.Environment]::Is64BitOperatingSystem -eq $false) {
    Write-Error 'The Calculatrix CLI requires a 64-bit operating system.'
    exit 1
}

# --- Collision check --------------------------------------------------------

$existing = Get-Command cx -ErrorAction SilentlyContinue
if ($existing -and $existing.Source -ne $exePath) {
    Write-Warning "'cx' already resolves to $($existing.Source), which is not $exePath."
    Write-Warning 'Installing anyway; check your PATH order if the wrong one runs afterward.'
}

# --- Fetch releases and pick the newest cli-v* one --------------------------

Write-Host '>>> Fetching releases...'
$releasesUrl = "https://api.github.com/repos/$repo/releases"
$headers = @{ Accept = 'application/vnd.github+json' }

# Unauthenticated, the GitHub API allows 60 requests an hour per address,
# which a shared network can exhaust. This header is for the API call only:
# it is deliberately not passed to the download below, because
# browser_download_url redirects to another host and Windows PowerShell 5.1
# preserves an Authorization header across a redirect, which would hand the
# token to a CDN.
if ($env:GITHUB_TOKEN) {
    $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN"
}

$releases = Invoke-RestMethod -Uri $releasesUrl -Headers $headers
$cliReleases = $releases | Where-Object { $_.tag_name -like 'cli-v*' }

if (-not $cliReleases) {
    Write-Error "No cli-v* release found in $repo."
    exit 1
}

# Sorted by parsed version rather than trusted API order (constraint 3 in
# the runbook, D31: this repository also publishes app releases, so
# /releases/latest is never called, and the newest cli-v* one is picked
# explicitly here instead of assuming the list already comes newest-first).
$release = $cliReleases |
    Sort-Object { [version]($_.tag_name -replace '^cli-v', '') } -Descending |
    Select-Object -First 1

if (-not $release) {
    Write-Error "No cli-v* release found in $repo."
    exit 1
}

$asset = $release.assets | Where-Object { $_.name -eq 'cx-windows-x64.zip' } | Select-Object -First 1

if (-not $asset) {
    Write-Error "No cx-windows-x64.zip asset found in release $($release.tag_name)."
    exit 1
}

Write-Host "    Release: $($release.tag_name)"
Write-Host "    Asset:   $($asset.name)"

# --- Download and extract ---------------------------------------------------

$tempZip = Join-Path $env:TEMP "cx-$($release.tag_name).zip"

Write-Host '>>> Downloading...'
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZip

# Clean previous installation
if (Test-Path $installDir) {
    Write-Host '>>> Removing previous installation...'
    Remove-Item -Recurse -Force $installDir
}

Write-Host '>>> Extracting...'
Expand-Archive -Path $tempZip -DestinationPath $installDir -Force
Remove-Item $tempZip

# --- Update PATH -------------------------------------------------------------

$userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')

if ($userPath -notlike "*$binDir*") {
    Write-Host '>>> Adding calculatrix\bin\ to PATH...'
    [System.Environment]::SetEnvironmentVariable(
        'PATH',
        "$userPath;$binDir",
        'User'
    )
    $env:PATH = "$env:PATH;$binDir"
}

# --- Verify -------------------------------------------------------------------

Write-Host '>>> Verifying installation...'
$versionOutput = & $exePath version
Write-Host "    $versionOutput"

Write-Host ''
Write-Host '>>> Calculatrix CLI installed successfully!'
Write-Host "    Location: $installDir"
Write-Host '    Restart your terminal to use `cx` from any directory.'
Write-Host ''
Write-Host "    RPN:      cx '2 3 +'   (one quoted program; it can leave several results: cx '2 sqrt 1 3 /')"
Write-Host "    Infix:    cx eval infix '2+3'"
Write-Host "    Values:   every value is a matrix, exact (1/3, 0.1) or approximate, marked ~ (~1.41421356237)"
Write-Host "    Discover: cx commands search <term>, cx commands show <word>; add --json for JSON output"
Write-Host '    More: cx --help'
