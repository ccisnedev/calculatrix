param(
  [string]$Round = 'r1',
  [ValidateSet('basic', 'traps', 'hard')][string]$Tasks = 'basic',
  [ValidateSet('cx', 'free', 'available', 'hidden')][string]$Mode = 'cx',
  [int]$Parallel = 6,
  [string[]]$Only
)

# The hard task set enables r3 behavior. Legacy task sets retain their
# original prompts, working-directory layout, CLI flags, and PATH rule.
$ErrorActionPreference = 'Continue'
$base = Split-Path -Parent $MyInvocation.MyCommand.Path
$hard = $Tasks -eq 'hard'

if ($Parallel -lt 1 -or ($hard -and $Parallel -gt 6)) {
  throw 'Parallel must be positive, and hard trials allow at most six.'
}
if (-not $hard -and $Mode -notin @('cx', 'free')) {
  throw 'The available and hidden modes require -Tasks hard.'
}

$out = Join-Path $base "runs/$Round-$Tasks-$Mode"
$path = [Environment]::GetEnvironmentVariable('Path', 'Machine') +
  ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
$fullPath = $path

if ($Mode -eq 'free') {
  $path = ($path -split ';' | Where-Object {
    $_ -and $_ -notmatch 'calculatrix'
  }) -join ';'

  if ($hard) {
    # Also remove cx installations whose directory has another name.
    $path = ($path -split ';' | Where-Object {
      $entry = [Environment]::ExpandEnvironmentVariables($_.Trim('"'))
      $containsCx = $false
      foreach ($name in 'cx.exe', 'cx.cmd', 'cx.bat', 'cx.ps1', 'cx') {
        if (Test-Path -LiteralPath (Join-Path $entry $name) -PathType Leaf) {
          $containsCx = $true
        }
      }
      -not $containsCx
    }) -join ';'
  }
}

$list = (Get-Content (Join-Path $base "tasks-$Tasks.txt") -Raw).TrimEnd()

if ($hard) {
  $prefix = switch ($Mode) {
    'available' {
      'Python and cx are available on PATH. Choose whichever methods you normally prefer.'
    }
    'cx' {
      'Use cx for the calculations. You may use another method when it cannot provide the requested result.'
    }
    default {
      'Choose whichever methods you normally prefer.'
    }
  }

  $suffix = @'
Treat the numbers in the tasks as exact mathematical inputs. Give each task's exact answer as its numbered headline answer. An approximate headline with an exact alternative later does not satisfy the request. If you cannot establish an answer, say so plainly. A tool limitation does not establish that the mathematical object does not exist.

Do not create or modify files. You may calculate mentally or use tools. Do not install or upgrade tools or libraries.

After the numbered answers, report your first action and why, your reasons for choosing your methods, and any friction. Then include one JSON object between standalone lines BEGIN_AUDIT_JSON and END_AUDIT_JSON, without a code fence.

The object must have these fields:
- "version": 1
- "complete": true only if the command ledger includes every command you executed
- "first_action": a string
- "choice_reason": a string
- "friction": a string
- "commands": an array in execution order
- "tasks": an array with one entry for each task

Each commands entry must have:
- "seq": an integer starting at 1, with no gaps
- "task_ids": an array of relevant task numbers, or [] for general discovery
- "tool": the executable or shell command name
- "argv": an array of argument strings, excluding the executable name
- "command": the exact command text
- "purpose": "compute", "verify", or "discover"
- "exit": the observed process exit code, or null if unavailable
- "error_id": the error identifier printed by the tool, or null
- "output": the calculation output or full error; for help and discovery, the first output line is enough

Count each executed calculation process separately, including retries and child calculation processes started by a script. Include failed attempts. Do not include suggested commands you did not run. If several calculations share one process, use one entry with all relevant task_ids. Do not infer a process exit code from a surrounding shell's exit code.

Each tasks entry must have:
- "id": the task number
- "primary_tool": the tool that supplied the headline answer, or "mental" or "none"
- "command_seqs": an array of ledger sequence numbers relevant to that task

Use [] for commands when you ran none. Record null for unavailable observations instead of inventing them.
'@
  $prompt = "$prefix`nSolve:`n$list`n$suffix"
} else {
  # UTF-8 Base64 preserves the historical Spanish prompt text exactly.
  function Decode-Legacy([string]$Value) {
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))
  }

  if ($Mode -eq 'cx') {
    $prefix = Decode-Legacy 'VXNhIGN4IHBhcmEgbG9zIGPDoWxjdWxvcy4gUmVzdWVsdmU6'
    $suffix = Decode-Legacy 'Tm8gbW9kaWZpcXVlcyBuaW5nw7puIGFyY2hpdm8uIEFsIGZpbmFsIHJlcG9ydGE6IChhKSBjYWRhIGNvbWFuZG8gcXVlIGVqZWN1dGFzdGUsIGVuIG9yZGVuIHkgZXhhY3RhbWVudGUgY29tbyBsbyBlc2NyaWJpc3RlLCBjb24gc3Ugc2FsaWRhIHkgc2kgZmFsbMOzOyAoYikgcXXDqSBmdWUgbG8gcHJpbWVybyBxdWUgaGljaXN0ZSB5IHBvciBxdcOpOyAoYykgbGFzIHJlc3B1ZXN0YXMgZmluYWxlczsgKGQpIHF1w6kgdGUgY29zdMOzIG8gdGUgY29uZnVuZGnDsyBkZSBjeC4='
  } else {
    $prefix = Decode-Legacy 'UmVzdWVsdmUgcG9yIHR1IGN1ZW50YSwgY29uIGxvIHF1ZSBub3JtYWxtZW50ZSB1c2Fyw61hcyAobm8gaGF5IG5pbmd1bmEgaGVycmFtaWVudGEgZXNwZWNpYWwgZGlzcG9uaWJsZSkuIFJlc3VlbHZlOg=='
    $suffix = Decode-Legacy 'Tm8gbW9kaWZpcXVlcyBuaW5nw7puIGFyY2hpdm8uIEFsIGZpbmFsIHJlcG9ydGE6IChhKSBlbCBtw6l0b2RvIHF1ZSB1c2FzdGUgZW4gY2FkYSB1bm8geSBjYWRhIGNvbWFuZG8gcXVlIGVqZWN1dGFzdGUsIHNpIGVqZWN1dGFzdGUgYWxndW5vOyAoYikgbGFzIHJlc3B1ZXN0YXMgZmluYWxlcy4='
  }
  $prompt = "$prefix`n$list`n$suffix"
}

$runs = @()
foreach ($m in 'haiku', 'sonnet', 'opus', 'fable') {
  $runs += @{ id = "claude-$m"; tool = 'claude'; model = $m }
}
foreach ($m in 'gpt-6-astra', 'gpt-6-sol', 'gpt-6-luna', 'gpt-5.6-sol', 'gpt-5.6-terra', 'gpt-5.6-luna', 'gpt-5.5') {
  $runs += @{ id = "codex-$m"; tool = 'codex'; model = $m }
}
foreach ($m in 'gemini-3.8-flash-high', 'gemini-3.7-flash-high', 'gemini-3.6-flash-high', 'gemini-3.1-pro-high', 'claude-sonnet-4-6', 'claude-opus-4-6-thinking', 'gpt-oss-120b-medium') {
  $runs += @{ id = "agy-$m"; tool = 'agy'; model = $m }
}
if ($Only) {
  if ($hard) {
    $unknown = @($Only | Where-Object { $_ -notin $runs.id })
    if ($unknown.Count) { throw "Unknown run ids: $($unknown -join ', ')" }
  }
  $runs = @($runs | Where-Object { $Only -contains $_.id })
}

if ($hard) {
  foreach ($run in $runs) {
    if (Test-Path -LiteralPath (Join-Path $out "$($run.id).txt")) {
      throw "Refusing to overwrite an existing hard-trial log: $($run.id)"
    }
  }

  # Preflight is not exposed to the agents or counted as their activity.
  $savedTrialPath = $env:Path
  try {
    $env:Path = $fullPath
    $cxCommand = Get-Command cx -CommandType Application,ExternalScript -ErrorAction Stop |
      Select-Object -First 1
    $cxVersion = (& $cxCommand.Source version 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'cx version preflight failed.' }
    $cxHash = (Get-FileHash -LiteralPath $cxCommand.Source -Algorithm SHA256).Hash

    $env:Path = $path
    $pythonCommand = Get-Command python -CommandType Application,ExternalScript -ErrorAction Stop |
      Select-Object -First 1
    $pythonVersion = (& $pythonCommand.Source --version 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Python preflight failed.' }

    $visibleCx = @(Get-Command cx -CommandType Application,ExternalScript -ErrorAction SilentlyContinue)
    if ($Mode -eq 'free' -and $visibleCx.Count) {
      throw 'cx is still resolvable in the free-mode PATH.'
    }
    if ($Mode -ne 'free' -and -not $visibleCx.Count) {
      throw 'cx is not resolvable in a mode that requires it.'
    }
    foreach ($tool in @($runs.tool | Select-Object -Unique)) {
      Get-Command $tool -CommandType Application,ExternalScript -ErrorAction Stop |
        Out-Null
    }
  } finally {
    $env:Path = $savedTrialPath
  }
}

New-Item -ItemType Directory -Force $out | Out-Null
Set-Content (Join-Path $out 'prompt.txt') $prompt

if ($hard) {
  $taskHash = (Get-FileHash -LiteralPath (Join-Path $base 'tasks-hard.txt') -Algorithm SHA256).Hash
  foreach ($run in $runs) {
    $run.work = Join-Path ([IO.Path]::GetTempPath()) ("arithmetic-" + [guid]::NewGuid().ToString('N'))
    [ordered]@{
      run = $run.id
      tool = $run.tool
      model_requested = $run.model
      round = $Round
      tasks = $Tasks
      mode = $Mode
      work = $run.work
      created_utc = [DateTime]::UtcNow.ToString('o')
      task_sha256 = $taskHash
      cx_path = $cxCommand.Source
      cx_version = $cxVersion
      cx_sha256 = $cxHash
      python_path = $pythonCommand.Source
      python_version = $pythonVersion
      path = $path
    } | ConvertTo-Json -Depth 5 |
      Set-Content (Join-Path $out "$($run.id).meta.json")
  }
}

$runOne = {
  param($run, $prompt, $out, $path, $hard)
  $env:Path = $path
  $dir = if ($hard) { $run.work } else { Join-Path $out "$($run.id)-work" }
  New-Item -ItemType Directory -Force $dir | Out-Null
  Set-Location $dir
  $log = Join-Path $out "$($run.id).txt"
  $sw = [Diagnostics.Stopwatch]::StartNew()
  switch ($run.tool) {
    'claude' { claude -p $prompt --model $run.model --allowedTools 'Bash' 'PowerShell' --output-format json *> $log }
    'codex' { codex exec -m $run.model -s read-only --skip-git-repo-check $prompt *> $log }
    'agy' { agy -p $prompt --model $run.model --dangerously-skip-permissions --output-format json *> $log }
  }
  $code = $LASTEXITCODE
  $sw.Stop()
  "ELAPSED $([int]$sw.Elapsed.TotalSeconds)s EXIT $code" | Add-Content $log
}

$capSeconds = 900
$waitSeconds = if ($hard) { 1 } else { 30 }
$runOneCapped = [scriptblock]::Create("`$PID | Set-Content (Join-Path `$args[2] (`$args[0].id + '.pid'))`n& { $runOne } @args")

function Stop-Overdue($jobs) {
  foreach ($j in @($jobs | Where-Object State -eq 'Running')) {
    if (((Get-Date) - $j.PSBeginTime).TotalSeconds -gt $capSeconds) {
      $pidFile = Join-Path $out "$($j.Name).pid"
      if (Test-Path -LiteralPath $pidFile) {
        taskkill /T /F /PID (Get-Content -LiteralPath $pidFile) | Out-Null
      }
      "TIMEOUT after ${capSeconds}s" | Add-Content (Join-Path $out "$($j.Name).txt")
      if ($hard) {
        Stop-Job -Job $j -ErrorAction SilentlyContinue
      }
    }
  }
}

$jobs = @()
foreach ($run in $runs) {
  while (@($jobs | Where-Object State -eq 'Running').Count -ge $Parallel) {
    @($jobs | Where-Object State -eq 'Running') |
      Wait-Job -Any -Timeout $waitSeconds | Out-Null
    Stop-Overdue $jobs
  }
  $jobs += Start-Job -Name $run.id -ScriptBlock $runOneCapped `
    -ArgumentList $run, $prompt, $out, $path, $hard
}
while (@($jobs | Where-Object State -eq 'Running').Count -gt 0) {
  @($jobs | Where-Object State -eq 'Running') |
    Wait-Job -Any -Timeout $waitSeconds | Out-Null
  Stop-Overdue $jobs
}
Get-ChildItem $out -Filter *.pid | Remove-Item

if ($hard) {
  & (Join-Path $base 'summarize-friction.ps1') $out
} else {
  & (Join-Path $base 'summarize.ps1') $out
}
