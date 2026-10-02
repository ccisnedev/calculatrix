param(
  [Parameter(Mandatory = $true)][string]$Out
)

# Emits objects. Pipe to Export-Csv or ConvertTo-Json as needed.
# Does not execute commands found in logs and does not modify files.
# Process-level metrics are explicitly agent-reported.
$ErrorActionPreference = 'Stop'

function Tool-Name([string]$Value) {
  $leaf = ($Value.Replace('\', '/') -split '/')[-1]
  ($leaf -replace '\.(exe|cmd|bat|ps1)$', '').ToLowerInvariant()
}

function Cx-Kind($Command) {
  $arguments = @($Command.argv | ForEach-Object { [string]$_ })
  $beforeSeparator = @()
  foreach ($argument in $arguments) {
    if ($argument -eq '--') { break }
    $beforeSeparator += $argument
  }

  if ($beforeSeparator -contains '--help' -or
      $beforeSeparator -contains '-h') {
    return 'help'
  }

  # Remove valueless global options for subcommand classification.
  $words = @($beforeSeparator | Where-Object { $_ -notin @('--json', '-q', '--quiet') })
  if ($words.Count -eq 0) { return 'other' }
  if ($words[0] -eq 'help') { return 'help' }
  if ($words[0] -in @('version', '--version', 'doctor')) { return 'other' }

  if ($words[0] -eq 'commands') {
    if ($words.Count -gt 1 -and $words[1] -in @('show', 'search', 'list')) {
      return $words[1]
    }
    return 'other'
  }
  return 'eval'
}

function Require-Fields($Object, [string[]]$Names) {
  foreach ($name in $Names) {
    if ($null -eq $Object -or $name -notin $Object.PSObject.Properties.Name) {
      throw "Missing field: $name"
    }
  }
}

function Check-Audit($Audit) {
  Require-Fields $Audit @(
    'version', 'complete', 'first_action', 'choice_reason',
    'friction', 'commands', 'tasks'
  )
  if ($Audit.version -ne 1 -or
      $Audit.complete -isnot [bool] -or -not $Audit.complete) {
    throw 'Expected version 1 and complete=true.'
  }
  if ($Audit.commands -isnot [array] -or $Audit.tasks -isnot [array]) {
    throw 'commands and tasks must be arrays.'
  }

  $sequence = 0
  $bySequence = @{}
  foreach ($command in $Audit.commands) {
    $sequence++
    Require-Fields $command @(
      'seq', 'task_ids', 'tool', 'argv', 'command',
      'purpose', 'exit', 'error_id', 'output'
    )
    if ($command.seq -ne $sequence) {
      throw 'Command sequence numbers must be contiguous and ordered.'
    }
    if ($command.task_ids -isnot [array] -or $command.argv -isnot [array]) {
      throw 'task_ids and argv must be arrays.'
    }
    if ($command.tool -isnot [string] -or
        [string]::IsNullOrWhiteSpace($command.tool) -or
        $command.command -isnot [string] -or
        $command.output -isnot [string]) {
      throw 'Command tool, command, and output must be strings.'
    }
    foreach ($argument in $command.argv) {
      if ($argument -isnot [string]) { throw 'argv entries must be strings.' }
    }
    if ($command.purpose -notin @('compute', 'verify', 'discover')) {
      throw 'Invalid command purpose.'
    }
    if ($null -ne $command.exit -and "$($command.exit)" -notmatch '^-?\d+$') {
      throw 'Exit must be an integer or null.'
    }
    if ($null -ne $command.error_id -and $command.error_id -isnot [string]) {
      throw 'error_id must be a string or null.'
    }
    foreach ($taskId in $command.task_ids) {
      if ($taskId -notin 1..11) { throw 'Invalid task id on a command.' }
    }
    $bySequence[$sequence] = $command
  }

  if ($Audit.tasks.Count -ne 11) { throw 'Expected 11 task records.' }
  $seen = @{}
  foreach ($task in $Audit.tasks) {
    Require-Fields $task @('id', 'primary_tool', 'command_seqs')
    if ($task.id -notin 1..11 -or $seen.ContainsKey([int]$task.id)) {
      throw 'Task ids must be unique and cover 1 through 11.'
    }
    $seen[[int]$task.id] = $true
    if ($task.primary_tool -isnot [string] -or
        [string]::IsNullOrWhiteSpace($task.primary_tool) -or
        $task.command_seqs -isnot [array]) {
      throw 'Invalid task attribution.'
    }

    $hasCxCompute = $false
    foreach ($number in $task.command_seqs) {
      if (-not $bySequence.ContainsKey([int]$number)) {
        throw 'Task references a missing command.'
      }
      $command = $bySequence[[int]$number]
      if ($task.id -notin $command.task_ids) {
        throw 'Task and command links disagree.'
      }
      if ((Tool-Name $command.tool) -eq 'cx' -and
          $command.purpose -eq 'compute' -and
          (Cx-Kind $command) -eq 'eval') {
        $hasCxCompute = $true
      }
    }
    if ((Tool-Name $task.primary_tool) -eq 'cx' -and -not $hasCxCompute) {
      throw 'A cx primary answer lacks a linked cx computation.'
    }
  }
}

$syntaxIds = @(
  'syntax-error', 'unknown-word', 'invalid-short-option',
  'extra-argument', 'stack-underflow'
)

$files = Get-ChildItem -LiteralPath $Out -Filter '*.txt' -File |
  Where-Object { $_.Name -match '^(claude|codex|agy)-.+\.txt$' } |
  Sort-Object Name

foreach ($file in $files) {
  $text = Get-Content -LiteralPath $file.FullName -Raw
  if ($null -eq $text) { $text = '' }
  $family = ($file.BaseName -split '-', 2)[0]

  $row = [ordered]@{
    run = $file.BaseName
    family = $family
    seconds = $null
    runner_exit = $null
    timeout = $false
    censored = $false
    cli_status = $null
    usage_input = $null
    usage_cache_create = $null
    usage_cache_read = $null
    usage_output = $null
    usage_thinking = $null
    usage_total = $null
    claude_effective_input = $null
    codex_reported_tokens = $null
    cost_usd = $null
    turns = $null
    native_shell_starts = $null
    native_shell_completions = $null
    native_shell_failed_completions = $null
    ledger_status = 'missing'
    ledger_error = $null
    reported_commands = $null
    reported_cx_calls = $null
    reported_cx_eval_calls = $null
    reported_cx_failed_known = $null
    reported_cx_outcome_unknown = $null
    reported_cx_failed = $null
    reported_cx_syntax_failures = $null
    reported_cx_help = $null
    reported_cx_show = $null
    reported_cx_search = $null
    reported_cx_list = $null
    reported_cx_expected_refusals = $null
    reported_cx_compute_use = $null
    reported_cx_verify_use = $null
    reported_cx_task_ids = $null
    reported_cx_primary_tasks = $null
    reported_first_compute_tool = $null
  }

  $elapsed = [regex]::Matches($text, '(?m)^ELAPSED (\d+)s EXIT ([^\r\n]*)\r?$')
  if ($elapsed.Count) {
    $last = $elapsed[$elapsed.Count - 1]
    $row.seconds = [int]$last.Groups[1].Value
    $value = $last.Groups[2].Value.Trim()
    if ($value) { $row.runner_exit = $value }
  }

  $timeout = [regex]::Match($text, '(?m)^TIMEOUT after (\d+)s\r?$')
  if ($timeout.Success) {
    $row.timeout = $true
    $row.censored = $true
    if ($null -eq $row.seconds) {
      $row.seconds = [int]$timeout.Groups[1].Value
    }
  }

  $report = $null
  if ($family -eq 'codex') {
    $report = $text
    $row.native_shell_starts =
      [regex]::Matches($text, '(?m)^exec\r?$').Count
    $row.native_shell_completions =
      [regex]::Matches($text, '(?m)^ (?:succeeded|exited -?\d+) in [^\r\n]*:\r?$').Count
    $row.native_shell_failed_completions =
      [regex]::Matches($text, '(?m)^ exited -?\d+ in [^\r\n]*:\r?$').Count

    # stdout and stderr can interleave. Preserve the CLI's aggregate name.
    $tokens = [regex]::Match(
      $text,
      '(?ms)^tokens used\r?\n.*?^\s*([0-9][0-9,]*)\s*$'
    )
    if ($tokens.Success) {
      $row.codex_reported_tokens =
        [long]($tokens.Groups[1].Value -replace ',', '')
    }
  } else {
    $envelope = $null
    $reportField = if ($family -eq 'claude') { 'result' } else { 'response' }

    foreach ($line in ($text -split "`n")) {
      if (-not $line.TrimStart().StartsWith('{')) { continue }
      try {
        $candidate = $line | ConvertFrom-Json -ErrorAction Stop
        if ($reportField -in $candidate.PSObject.Properties.Name -and
            'usage' -in $candidate.PSObject.Properties.Name) {
          $envelope = $candidate
        }
      } catch {
        # Non-envelope diagnostic lines do not become fake usage records.
      }
    }

    if ($null -ne $envelope) {
      $report = [string]$envelope.$reportField
      $usage = $envelope.usage
      $row.usage_input = $usage.input_tokens
      $row.usage_output = $usage.output_tokens
      $row.turns = $envelope.num_turns

      if ($family -eq 'claude') {
        $row.cli_status = $envelope.subtype
        $row.usage_cache_create = $usage.cache_creation_input_tokens
        $row.usage_cache_read = $usage.cache_read_input_tokens
        $row.usage_thinking = $usage.output_tokens_details.thinking_tokens
        $row.cost_usd = $envelope.total_cost_usd
        if ($null -ne $row.usage_input -and
            $null -ne $row.usage_cache_create -and
            $null -ne $row.usage_cache_read) {
          $row.claude_effective_input =
            [long]$row.usage_input +
            [long]$row.usage_cache_create +
            [long]$row.usage_cache_read
        }
      } else {
        $row.cli_status = $envelope.status
        $row.usage_cache_read = $usage.cache_read_tokens
        $row.usage_thinking = $usage.thinking_tokens
        $row.usage_total = $usage.total_tokens
      }
    }
  }

  if ($null -ne $report) {
    $blocks = [regex]::Matches(
      $report,
      '(?ms)^BEGIN_AUDIT_JSON[ \t]*\r?\n(.*?)^END_AUDIT_JSON[ \t]*\r?$'
    )

    if ($blocks.Count) {
      try {
        $audit = $blocks[$blocks.Count - 1].Groups[1].Value |
          ConvertFrom-Json -ErrorAction Stop
        Check-Audit $audit

        $commands = @($audit.commands)
        $cx = @($commands | Where-Object { (Tool-Name $_.tool) -eq 'cx' })
        $evals = @($cx | Where-Object { (Cx-Kind $_) -eq 'eval' })
        $failed = @($cx | Where-Object {
          ($null -ne $_.exit -and [long]$_.exit -ne 0) -or
          -not [string]::IsNullOrWhiteSpace([string]$_.error_id)
        })
        $unknown = @($cx | Where-Object {
          $null -eq $_.exit -and
          [string]::IsNullOrWhiteSpace([string]$_.error_id)
        })
        $compute = @($evals | Where-Object {
          $_.purpose -eq 'compute' -and $_.task_ids.Count -gt 0
        })
        $verify = @($evals | Where-Object {
          $_.purpose -eq 'verify' -and $_.task_ids.Count -gt 0
        })
        $allCompute = @($commands | Where-Object { $_.purpose -eq 'compute' })
        $taskIds = @(
          $compute | ForEach-Object { $_.task_ids } | Sort-Object -Unique
        )

        $row.ledger_status = 'complete_reported'
        $row.reported_commands = $commands.Count
        $row.reported_cx_calls = $cx.Count
        $row.reported_cx_eval_calls = $evals.Count
        $row.reported_cx_failed_known = $failed.Count
        $row.reported_cx_outcome_unknown = $unknown.Count
        if ($unknown.Count -eq 0) {
          $row.reported_cx_failed = $failed.Count
        }
        $row.reported_cx_syntax_failures =
          @($failed | Where-Object { $_.error_id -in $syntaxIds }).Count
        $row.reported_cx_help =
          @($cx | Where-Object { (Cx-Kind $_) -eq 'help' }).Count
        $row.reported_cx_show =
          @($cx | Where-Object { (Cx-Kind $_) -eq 'show' }).Count
        $row.reported_cx_search =
          @($cx | Where-Object { (Cx-Kind $_) -eq 'search' }).Count
        $row.reported_cx_list =
          @($cx | Where-Object { (Cx-Kind $_) -eq 'list' }).Count
        $row.reported_cx_expected_refusals = @($failed | Where-Object {
          $_.error_id -eq 'complex-result' -and
          $_.task_ids.Count -gt 0 -and
          @($_.task_ids | Where-Object { $_ -notin @(10, 11) }).Count -eq 0
        }).Count
        $row.reported_cx_compute_use = $compute.Count -gt 0
        $row.reported_cx_verify_use = $verify.Count -gt 0
        $row.reported_cx_task_ids = $taskIds -join ','
        $row.reported_cx_primary_tasks = @($audit.tasks | Where-Object {
          (Tool-Name $_.primary_tool) -eq 'cx'
        }).Count
        $row.reported_first_compute_tool = if ($allCompute.Count) {
          Tool-Name $allCompute[0].tool
        } else {
          'none'
        }
      } catch {
        $row.ledger_status = 'invalid_or_incomplete'
        $row.ledger_error = $_.Exception.Message
      }
    }
  }

  [pscustomobject]$row
}
