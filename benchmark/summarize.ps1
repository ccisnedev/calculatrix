param([string]$Out)
# One row per run: elapsed seconds, exit code, tokens (input incl. cache, output) and cost when reported.
Get-ChildItem $Out -Filter *.txt | Where-Object Name -ne 'prompt.txt' | ForEach-Object {
  $text = Get-Content $_.FullName -Raw
  $row = [ordered]@{ run = $_.BaseName; seconds = $null; exit = $null; tokens_in = $null; tokens_out = $null; cost_usd = $null; turns = $null }
  if ($text -match 'ELAPSED (\d+)s EXIT (\S*)') { $row.seconds = [int]$Matches[1]; $row.exit = $Matches[2] }
  if ($_.BaseName -like 'codex-*') {
    # stdout and stderr interleave: the count is the first bare number line after "tokens used".
    if ($text -match '(?s)tokens used.*?(?m:^\s*([\d,]{4,})\s*$)') { $row.tokens_in = [int]($Matches[1] -replace ',', '') }
  } else {
    $json = ($text -split "`n" | Where-Object { $_.TrimStart().StartsWith('{') } | Select-Object -Last 1)
    if ($json) {
      try {
        $j = $json | ConvertFrom-Json
        $u = $j.usage
        if ($_.BaseName -like 'claude-*') {
          $row.tokens_in = $u.input_tokens + $u.cache_creation_input_tokens + $u.cache_read_input_tokens
          $row.tokens_out = $u.output_tokens; $row.cost_usd = $j.total_cost_usd; $row.turns = $j.num_turns
        } else {
          $row.tokens_in = $u.input_tokens + $u.cache_read_tokens
          $row.tokens_out = $u.output_tokens + $u.thinking_tokens; $row.turns = $j.num_turns
        }
      } catch { }
    }
  }
  [pscustomobject]$row
} | Sort-Object run | Format-Table -AutoSize
