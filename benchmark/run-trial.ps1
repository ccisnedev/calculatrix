param(
  [string]$Round = 'r1',
  [ValidateSet('basic', 'traps')][string]$Tasks = 'basic',
  [ValidateSet('cx', 'free')][string]$Mode = 'cx',
  [int]$Parallel = 6,
  [string[]]$Only
)
# Runs claude, codex and agy models on one task set, with cx from a fresh PATH (cx mode)
# or with whatever the agent normally uses (free mode). Records time and tokens.
# Results go to runs/<round>-<tasks>-<mode>, which git ignores.
$ErrorActionPreference = 'Continue'
$base = Split-Path -Parent $MyInvocation.MyCommand.Path
$out = Join-Path $base "runs/$Round-$Tasks-$Mode"
New-Item -ItemType Directory -Force $out | Out-Null
$path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
if ($Mode -eq 'free') { $path = ($path -split ';' | Where-Object { $_ -and $_ -notmatch 'calculatrix' }) -join ';' }
$list =(Get-Content (Join-Path $base "tasks-$Tasks.txt") -Raw).TrimEnd()
if ($Mode -eq 'cx') {
  $prompt = "Usa cx para los cálculos. Resuelve:`n$list`nNo modifiques ningún archivo. Al final reporta: (a) cada comando que ejecutaste, en orden y exactamente como lo escribiste, con su salida y si falló; (b) qué fue lo primero que hiciste y por qué; (c) las respuestas finales; (d) qué te costó o te confundió de cx."
} else {
  $prompt = "Resuelve por tu cuenta, con lo que normalmente usarías (no hay ninguna herramienta especial disponible). Resuelve:`n$list`nNo modifiques ningún archivo. Al final reporta: (a) el método que usaste en cada uno y cada comando que ejecutaste, si ejecutaste alguno; (b) las respuestas finales."
}
Set-Content (Join-Path $out 'prompt.txt') $prompt

$runs = @()
foreach ($m in 'haiku', 'sonnet', 'opus', 'fable') { $runs += @{ id = "claude-$m"; tool = 'claude'; model = $m } }
foreach ($m in 'gpt-6-astra', 'gpt-6-sol', 'gpt-6-luna', 'gpt-5.6-sol', 'gpt-5.6-terra', 'gpt-5.6-luna', 'gpt-5.5') { $runs += @{ id = "codex-$m"; tool = 'codex'; model = $m } }
foreach ($m in 'gemini-3.8-flash-high', 'gemini-3.7-flash-high', 'gemini-3.6-flash-high', 'gemini-3.1-pro-high', 'claude-sonnet-4-6', 'claude-opus-4-6-thinking', 'gpt-oss-120b-medium') { $runs += @{ id = "agy-$m"; tool = 'agy'; model = $m } }
if ($Only) { $runs = $runs | Where-Object { $Only -contains $_.id } }

$runOne = {
  param($run, $prompt, $out, $path)
  $env:Path = $path
  $dir = Join-Path $out "$($run.id)-work"
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
$runOneCapped = [scriptblock]::Create("`$PID | Set-Content (Join-Path `$args[2] (`$args[0].id + '.pid'))`n& { $runOne } @args")
function Stop-Overdue($jobs) {
  foreach ($j in @($jobs | Where-Object State -eq 'Running')) {
    if (((Get-Date) - $j.PSBeginTime).TotalSeconds -gt $capSeconds) {
      $pidFile = Join-Path $out "$($j.Name).pid"
      if (Test-Path $pidFile) { taskkill /T /F /PID (Get-Content $pidFile) | Out-Null }
      "TIMEOUT after ${capSeconds}s" | Add-Content (Join-Path $out "$($j.Name).txt")
    }
  }
}
$jobs = @()
foreach ($run in $runs) {
  while (@($jobs | Where-Object State -eq 'Running').Count -ge $Parallel) { @($jobs | Where-Object State -eq 'Running') | Wait-Job -Any -Timeout 30 | Out-Null; Stop-Overdue $jobs }
  $jobs += Start-Job -Name $run.id -ScriptBlock $runOneCapped -ArgumentList $run, $prompt, $out, $path
}
while (@($jobs | Where-Object State -eq 'Running').Count -gt 0) { @($jobs | Where-Object State -eq 'Running') | Wait-Job -Any -Timeout 30 | Out-Null; Stop-Overdue $jobs }
Get-ChildItem $out -Filter *.pid | Remove-Item
& (Join-Path $base 'summarize.ps1') $out
