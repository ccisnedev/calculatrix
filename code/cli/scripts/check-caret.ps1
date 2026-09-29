# check-caret.ps1: regression check for issue #22 (`cx`, not `calculatrix`,
# and no `.cmd`/`.bat` alias shim of any kind, because such a shim runs
# through cmd.exe, which consumes `^` while parsing the command line before
# the shim body ever runs).
#
# Requires `cx` already installed and on PATH (run scripts\dev-install.ps1
# first, then open a new terminal so the PATH change takes effect).
#
# Usage: .\scripts\check-caret.ps1
# Exit 0 when both invocations below print the expected sqrt(2) and exit 0;
# exit 1 otherwise, printing what actually happened.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expected = '1: 1.4142135623730951'
$anyFailed = $false

function Test-CaretInvocation {
    param(
        [Parameter(Mandatory = $true)] [string] $Label,
        [Parameter(Mandatory = $true)] [string] $Output,
        [Parameter(Mandatory = $true)] [int] $ExitCode
    )

    $trimmed = ($Output | Out-String).Trim()
    if ($ExitCode -eq 0 -and $trimmed -eq $expected) {
        Write-Host "PASS ($Label): '$trimmed', exit $ExitCode"
        return $true
    }

    Write-Host "FAIL ($Label): expected '$expected', exit 0"
    Write-Host "FAIL ($Label): got      '$trimmed', exit $ExitCode"
    return $false
}

# PowerShell: cx eval infix '2^0.5'. '2^0.5' has no spaces, so PowerShell
# passes it to cx unquoted on the underlying command line.
$psOutput = & cx eval infix '2^0.5' 2>&1
$psExit = $LASTEXITCODE
if (-not (Test-CaretInvocation -Label 'PowerShell' -Output $psOutput -ExitCode $psExit)) {
    $anyFailed = $true
}

# cmd.exe: cx eval infix "2^0.5", quoted, which is what the README asks
# cmd.exe users to do; cmd.exe strips the quotes and cx receives 2^0.5.
$cmdOutput = & cmd /c 'cx eval infix "2^0.5"' 2>&1
$cmdExit = $LASTEXITCODE
if (-not (Test-CaretInvocation -Label 'cmd.exe' -Output $cmdOutput -ExitCode $cmdExit)) {
    $anyFailed = $true
}

if ($anyFailed) {
    Write-Host "check-caret: FAILED"
    exit 1
}

Write-Host "check-caret: PASSED"
exit 0
