[CmdletBinding()]
param(
    [ValidateRange(16, 4096)]
    [int]$Size = 512
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-BrowserExecutable {
    $candidates = @(
        "$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "$env:LocalAppData\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles (x86)\Google\Chrome\Application\chrome.exe",
        "$env:LocalAppData\Google\Chrome\Application\chrome.exe"
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }

    throw 'No se encontro Microsoft Edge o Google Chrome para renderizar el SVG.'
}

$scriptRoot = $PSScriptRoot
$appRoot = (Resolve-Path (Join-Path $scriptRoot '..')).Path
$svgPath = (Resolve-Path (Join-Path $scriptRoot '..\..\design\logo.svg')).Path
$pngPath = Join-Path $appRoot 'assets\icon.png'
$configPath = Join-Path $appRoot 'flutter_launcher_icons.yaml'
$browserPath = Get-BrowserExecutable

$pngDirectory = Split-Path -Parent $pngPath
if (-not (Test-Path $pngDirectory)) {
    New-Item -ItemType Directory -Path $pngDirectory | Out-Null
}

$svgUri = [System.Uri]::new($svgPath).AbsoluteUri
$tempHtmlPath = Join-Path ([System.IO.Path]::GetTempPath()) ("calculatrix-icon-{0}.html" -f [System.Guid]::NewGuid().ToString('N'))
$htmlContent = @"
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="utf-8">
        <style>
            html, body {
                margin: 0;
                width: 100%;
                height: 100%;
                overflow: hidden;
                background: transparent;
            }

            img {
                display: block;
                width: 100vw;
                height: 100vh;
            }
        </style>
    </head>
    <body>
        <img src="$svgUri" alt="Calculatrix logo">
    </body>
</html>
"@
Set-Content -Path $tempHtmlPath -Value $htmlContent -Encoding UTF8
$renderUri = [System.Uri]::new($tempHtmlPath).AbsoluteUri

$browserArguments = @(
    '--headless',
    '--disable-gpu',
    '--hide-scrollbars',
    '--default-background-color=00000000',
    '--force-device-scale-factor=1',
    "--window-size=$Size,$Size",
    "--screenshot=$pngPath",
        $renderUri
)

try {
        $browserProcess = Start-Process -FilePath $browserPath -ArgumentList $browserArguments -Wait -PassThru
        if ($browserProcess.ExitCode -ne 0) {
                throw "El render del SVG fallo con codigo $($browserProcess.ExitCode)"
        }
}
finally {
        if (Test-Path $tempHtmlPath) {
                Remove-Item $tempHtmlPath -Force
        }
}

if (-not (Test-Path $pngPath)) {
    throw "No se pudo generar $pngPath"
}

Add-Type -AssemblyName System.Drawing
$image = [System.Drawing.Image]::FromFile($pngPath)
try {
    if ($image.Width -ne $Size -or $image.Height -ne $Size) {
        throw "Se esperaba un PNG de ${Size}x${Size}px y se obtuvo $($image.Width)x$($image.Height)px"
    }
}
finally {
    $image.Dispose()
}

Push-Location $appRoot
try {
    dart run flutter_launcher_icons -f (Split-Path -Leaf $configPath)
}
finally {
    Pop-Location
}