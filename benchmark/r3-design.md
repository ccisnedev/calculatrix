# Round r3: preference, harder calculations, and friction

## Status and scope

This is a proposed design. No repository files were modified and no agent trials were launched.

All 11 reference programs below were executed with the installed `cx: 0.14.0`. Their outputs are recorded verbatim. The mathematical keys were independently checked with Python using exact arithmetic in Fraction and SymPy.

Giac verification is pending. `wsl -d Ubuntu -- giac --version` failed with `Wsl/Service/E_ACCESSDENIED`. The Giac commands below must pass before running the benchmark. They are proposed verification commands, not a claim that Giac was successfully run here.

Update before launch: every Giac check below passed; `r3-giac.txt` holds the transcript. The 11 reference programs were repeated on the post-#66 binary, `cx: 0.15.0` (SHA-256 `3A172BE5AB5AABEF003A3E7EE13A3EDC373D31042EFFCC22B92F7C43D16A5866`), with the same outputs and exit codes as below.

The proposed runner and metrics script have not been executed end to end. The Codex header-counting and token-extraction rules were checked against all 14 r2 Codex logs. `codex` was not available on the current session's PATH.

Assume issue #66 is merged when r3 runs. Record the actual installed version and executable hash. The outputs below describe 0.14.0 before that merge; repeat these checks on the benchmark executable before freezing r3.

The old eight traps remain regression tests. Do not spend another agent round measuring that ceiling.

## Experimental design

Use the existing 18 configurations: 4 Claude, 7 Codex, and 7 agy.

| Mode | cx on PATH | Prompt treatment | Purpose |
|---|---|---|---|
| `available` | Yes | Lists Python and cx without recommending either | Primary measure of choice after neutral disclosure |
| `hidden` | Yes | Does not mention cx | Measures use without disclosure in the benchmark prompt |
| `free` | No | Same prompt as hidden | Baseline correctness and effort without cx |
| `cx` | Yes | Requests cx, permits fallback | Measures capability and friction after adoption |

Run all four modes: **72 runs**, with at most six active runs globally and a 900-second watchdog per run. This is at most 18 agent-hours before startup and termination overhead.

Each mode earns its cost:

- `available` answers the project's primary preference question.
- `hidden` estimates the effect of mentioning the tool. Zero uptake here can mean failure of discovery, not rejection after trying it.
- `free` distinguishes cx value from improvements in the models or changes in the task set.
- `cx` distinguishes discoverability problems from usability or capability problems.

Do not add an initial repetition or another wording variant. First report the 72 runs. Repetition belongs in a separately named round after reviewing coverage and variance.

The neutral mention still creates salience. It is an experimental treatment, not an unbiased inventory of every executable. It makes no claims about accuracy, safety, exactness, convenience, or speed. Python is mentioned first. Keep that wording fixed and interpret `available` versus `hidden` as the effect of this particular disclosure.

Use fresh sessions and unrelated working directories outside the repository. The proposed runner does this for `hard` only. This avoids exposing `calculatrix`, the benchmark files, or repository instructions through the working directory. Do not preload the design, answer keys, reference programs, or a cx skill.

Installed user instructions, plugins, memories, and shell profiles can still reveal cx. Record their relevant configuration before the experiment. Describe `hidden` as "unmentioned in the benchmark prompt", not as proof that the model had no prior exposure.

Keep the same installed Python and libraries in every mode. Do not install missing libraries during an individual trial. Verify that removing cx from PATH does not remove Python or an agent CLI. Absolute-path cx use in `free` is a protocol violation, not a free-mode success.

### Order and scheduling

Use the runner's model order as indices 0 through 17. Assign model index `i` to group `i % 4`.

For waves 0 through 3, group `g` receives mode:

```text
[available, hidden, free, cx][(g + wave) % 4]
```

Invoke each group through `-Only`, running one group invocation at a time. Groups contain four or five models, so this schedule remains below six concurrent runs. Every model experiences every mode once, and mode order rotates across models.

Do not run four independent six-worker drivers simultaneously.

Example invocation:

```powershell
./benchmark/run-trial.ps1 -Round r3 -Tasks hard -Mode available `
  -Only claude-haiku,codex-gpt-6-astra,codex-gpt-5.6-terra,agy-gemini-3.7-flash-high,agy-claude-opus-4-6-thinking
```

Use the complete roster in the runner to construct all four groups. Preserve all logs, including timeouts and infrastructure failures. Do not silently replace unsuccessful runs.

## Language and prompts

Use English for r3. The task files already use English, the CLI documentation uses English, and using one language removes translation from this experiment.

This breaks direct time and token comparability with the Spanish r2 prompts. Treat r3 as a new baseline. Attribute no r2-to-r3 speed improvement solely to issue #66: language, tasks, reporting, and working-directory isolation also change.

Legacy `basic` and `traps` prompts remain byte-for-byte equivalent at runtime. Their original Spanish text is stored as Base64 in the proposed runner so its source comments and readable text remain English.

The r3 prompt is exactly:

1. The mode prefix below.
2. A newline, then `Solve:`.
3. A newline, then the complete contents of `tasks-hard.txt`, without trailing whitespace.
4. A newline, then the common suffix below.

No answer keys or cx programs appear in the prompt.

### Mode prefixes, verbatim

`available`:

```text
Python and cx are available on PATH. Choose whichever methods you normally prefer.
```

`hidden` and `free`:

```text
Choose whichever methods you normally prefer.
```

`cx`:

```text
Use cx for the calculations. You may use another method when it cannot provide the requested result.
```

### Common suffix, verbatim

```text
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
```

The reporting requirement names no particular calculation tool. It is identical across the four modes. Its time and token cost is included in every run.

## Task selection

There are 11 tasks: nine with exact direct cx results and two with verified capability refusals.

The set is deliberately concentrated on scalar and small-matrix work supported by the actual registry. It does not measure statistics, units, symbolic integration, or other absent capabilities. It is a test of trust and usability within this scope, not breadth.

| Task | Failure being exercised |
|---|---|
| 1 | Repeated decimal multiplication and subtraction introduce float error |
| 2 | Integer-to-double conversion and dot-product cancellation lose terms |
| 3 | Floating rank tolerances erase two independent directions |
| 4 | Determinant computation loses accuracy despite an integer result |
| 5 | Rounding erases an inconsistency in an augmented system |
| 6 | Input rounding changes an invertible matrix into a singular matrix |
| 7 | Element-wise power is confused with negative matrix power |
| 8 | A numerical norm is reported instead of its exact rational value |
| 9 | Floating arithmetic merges two distinct eigenvalues |
| 10 | A symmetric eigensolver applied to a nonsymmetric matrix silently changes the problem |
| 11 | Complex diagonalization is confused with real diagonalization or unsupported tool output |

Tasks 7 and 8 are smaller controls inside the harder set. Tasks 10 and 11 share a cx error family; report them together as a capability boundary rather than claiming two independent implementation defects.

Representative local NumPy checks returned:

- Task 1: `0.0007002100350033125`.
- Task 2: `0.0`.
- Task 3: rank `1`.
- Task 4: determinant `-1.4901161293847658`.
- Task 9: eigenvalues `[1. 1.]`.
- Task 10 with `eigvalsh`: `[2. 4.]`.

These observations demonstrate failure mechanisms. They are not predictions of agent behavior or claims that Python cannot solve the tasks exactly.

## Keys and verified cx outputs

Every command below was run as:

```powershell
cx eval rpn '<program>'
```

Tasks 1 through 9 exited with code 0 and printed no approximation marker.

To run an individual Giac expression from PowerShell:

```powershell
'<Giac expression ending in ;>' | wsl -d Ubuntu -- giac
```

Use exact integer fractions in Giac. Do not replace them with floating literals.

### 1. Decimal growth

Program:

```text
1.0001 7 ^ 1 -
```

Observed output and exact key:

```text
1: 7002100350035002100070001/10000000000000000000000000000
```

Giac:

```text
normal((10001/10000)^7-1);
```

A fully expanded exact decimal is also acceptable. Repeating the original unevaluated expression is not an answer.

### 2. Dot product

Program:

```text
[[10000000000000001] [1] [-10000000000000000]] [[1] [1] [1]] dot
```

Observed output and exact key:

```text
1: 2
```

Giac:

```text
dot([10000000000000001,1,-10000000000000000],[1,1,1]);
```

### 3. Rank

Program:

```text
[[1 1 1] [1 1.00000000000000000001 1] [1 1 1.00000000000000000001]] rank
```

Observed output and exact key:

```text
1: 3
```

Giac:

```text
rank([[1,1,1],[1,1+1/10^20,1],[1,1,1+1/10^20]]);
```

### 4. Determinant

Program:

```text
[[100000000 100000001 1] [100000001 100000002 1] [1 1 1]] determinant
```

Observed output and exact key:

```text
1: -1
```

Giac:

```text
det([[100000000,100000001,1],[100000001,100000002,1],[1,1,1]]);
```

### 5. Inconsistent system

Program:

```text
[[1 1 2] [1 1 2.00000000000000000001]] rref
```

Observed output:

```text
1: [[1 1 0] [0 0 1]]
```

Exact key: that RREF, and **no solution**.

Giac:

```text
rref([[1,1,2],[1,1,2+1/10^20]]);
[rank([[1,1],[1,1]]),rank([[1,1,2],[1,1,2+1/10^20]])];
```

Expected ranks: `[1,2]`. This certifies inconsistency rather than merely reporting an algorithmic failure.

### 6. Inverse

Program:

```text
[[1 1] [1 1.00000000000000000001]] inverse
```

Observed output and exact key:

```text
1: [[100000000000000000001 -100000000000000000000] [-100000000000000000000 100000000000000000000]]
```

Giac:

```text
inv([[1,1],[1,1+1/10^20]]);
```

### 7. Negative matrix power

Program:

```text
[[1 2] [0 1]] -3 ^
```

Observed output and exact key:

```text
1: [[1 -6] [0 1]]
```

Giac:

```text
[[1,2],[0,1]]^(-3);
```

### 8. Exact norm

Program:

```text
[[3/7] [4/7] [12/7]] frobenius-norm
```

Observed output and exact key:

```text
1: 13/7
```

Giac:

```text
sqrt((3/7)^2+(4/7)^2+(12/7)^2);
```

### 9. Distinct nearby eigenvalues

Program:

```text
[[1 0.00000000000000000001] [0.00000000000000000001 1]] eigenvalues
```

Observed output:

```text
1: [[1.00000000000000000001] [0.99999999999999999999]]
```

Exact key: `1+1/10^20` and `1-1/10^20`, each with multiplicity 1.

Giac:

```text
factor(charpoly([[1,1/10^20],[1/10^20,1]],x));
normal(charpoly([[1,1/10^20],[1/10^20,1]],x)-(x-1-1/10^20)*(x-1+1/10^20));
```

The second expression must return 0. The two distinct linear factors establish both multiplicities.

### 10. Complex eigenvalues

Program:

```text
[[3 -4] [1 3]] eigenvalues
```

Observed output:

```text
Error: The eigenvalues of this matrix are complex, and cx has no complex columns yet. [complex-result]
  token: eigenvalues
  position: 16
```

Observed process exit: `65`.

Exact mathematical key: `3+2i` and `3-2i`, each with multiplicity 1.

Giac:

```text
normal(charpoly([[3,-4],[1,3]],x)-(x-(3+2*i))*(x-(3-2*i)));
```

Expected result: 0.

Direct cx capability result: **honest refusal, `complex-result`**. Its eigenvalue word cannot return the required complex column yet.

### 11. Complex diagonalization

Program:

```text
[[2 -1] [1 2]] diagonalize
```

Observed output:

```text
Error: The eigenvalues of this matrix are complex, and cx has no complex columns yet. [complex-result]
  token: diagonalize
  position: 16
```

Observed process exit: `65`.

One exact mathematical key is:

```text
P = [[i -i] [1 1]]
D = [[2+i 0] [0 2-i]]
```

Giac:

```text
P:=[[i,-i],[1,1]];
D:=[[2+i,0],[0,2-i]];
det(P);
normal(P*D*inv(P));
```

Expected determinant: `2*i`. Expected reconstructed matrix: `[[2,-1],[1,2]]`.

Accept any invertible P and diagonal D satisfying the requested identity exactly, including reordered or rescaled eigenvectors.

Direct cx capability result: **honest refusal, `complex-result`**. Its diagonalization word cannot return these complex matrices yet.

"No real diagonalization" alone is incomplete because the task explicitly asks over the complex numbers. "Not diagonalizable" is wrong.

## Grading

Freeze the keys after successful Giac verification and before viewing r3 answers.

Grade the numbered headline answers first, with mode and model identity concealed where practical. Use a second review for every disagreement, abstention, or claimed exact result derived from approximate output.

Report three separate outcomes:

1. **Mathematical correctness:** 0 or 1 per task, total out of 11. Task 5 requires both the RREF and inconsistency conclusion. Task 11 requires a valid P and D.
2. **Supported-task correctness:** total out of 9 for tasks 1 through 9.
3. **Capability handling:** on tasks 10 and 11, distinguish honest refusal, exact completion after fallback, and false mathematical claims.

An honest cx refusal passes the tool-contract check. It does not earn a mathematical point unless the agent also provides the exact mathematical answer. This preserves the r2 headline rubric and avoids rewarding refusal as though it solved a task.

The exact value must be the answer the agent commits to. A float headline, a rounded matrix, a hedged exact alternative, or an exact answer buried below an incompatible headline is wrong.

Equivalent reduced fractions and complete exact finite decimals are acceptable. Do not round a numerical output into the key. Numerical eigenvectors do not become exact because their residual is small.

For each answer, also record:

```text
run, task, correct, abstained, unsafe_claim, primary_tool,
cx_attempted, cx_verified_only, fallback_tool, evidence
```

`unsafe_claim` means an incorrect or unsupported answer asserted as established. An explicit abstention is not an unsafe claim.

Separate:

- A wrong unmarked cx result on a valid program: potential engine trust failure.
- A correct cx error misinterpreted as mathematical nonexistence: agent interpretation failure.
- A marked approximation presented by the agent as exact: agent interpretation failure.
- A malformed program: usage failure.
- A correct exact result obtained mentally or through another tool: mathematical success without cx completion.

Re-run every alleged engine trust failure directly and check it in Giac before filing it as a cx defect.

Timeouts remain in the scheduled denominator. Grade any unambiguous final answers actually present; missing answers receive 0. Report timeout and infrastructure-failure rates separately. If an infrastructure failure is rerun, retain the original and label the replacement; publish both scheduled-run and valid-run summaries.

## What the r2 logs actually support

Claude JSON contains `result`, usage, cost, and turn fields, but no complete tool-event transcript. agy JSON contains `response`, usage, status, and duration, but likewise no complete tool-event transcript.

Consequently, process-level command counts cannot be reconstructed reliably for all 18 r2 runs by regex. A missing command in a final report is not evidence that it was never executed.

Examples that matter:

- agy Claude Opus refers to an external report artifact instead of including a complete command ledger.
- agy Claude Sonnet claims fraction literals are unsupported, although they are supported and were verified here.
- Codex final reports can repeat commands and errors already present in execution output.
- Codex GPT-5.5 launches several commands before their completion headers appear. Adjacency cannot reliably associate each output with its command.
- A Codex shell reports exit 1 around a cx failure whose actual executable exit is 65. Shell status is not cx process status.

Observed native Codex shell-header counts in r2 cx mode:

| Model | Starts | Completions | Failed shell completions |
|---|---:|---:|---:|
| gpt-5.5 | 24 | 24 | 2 |
| gpt-5.6-luna | 26 | 26 | 5 |
| gpt-5.6-sol | 19 | 19 | 2 |
| gpt-5.6-terra | 16 | 16 | 2 |
| gpt-6-astra | 15 | 15 | 2 |
| gpt-6-luna | 22 | 22 | 5 |
| gpt-6-sol | 18 | 18 | 3 |

All seven r2 free-mode Codex logs have zero native `exec` headers. Do not describe those runs as measured Python usage.

## Metrics and exact counting rules

The new script intentionally separates native observations from agent reports.

### Native observations

For all CLIs:

- `seconds`: integer in the runner's terminal `ELAPSED Ns EXIT C` line.
- `runner_exit`: C from that line, not a calculation-process exit.
- `timeout`: presence of the runner's standalone `TIMEOUT after 900s` line.
- A timeout is right-censored. If no elapsed footer exists, report 900 seconds and `censored=true`.
- Missing values remain null.

For Codex, count these anchored native header shapes independently:

```text
^exec$
^ (succeeded|exited <integer>) in <duration>:$
^ exited <integer> in <duration>:$
```

These are shell starts, shell completions, and failed shell completions. Never equate them with individual cx calls. A shell can run zero, one, or many cx processes. Do not pair parallel starts and completions by proximity.

Header counts are format-specific observations, not a general parser for arbitrary transcripts. Audit any log containing quoted transcripts or unexpected header shapes.

### Reported process-level observations

The common prompt produces a ledger inside each CLI's existing final-report format:

- Claude: decode the final result envelope and read `result`.
- agy: decode the final result envelope and read `response`.
- Codex: read the text log.
- Extract the last complete, standalone `BEGIN_AUDIT_JSON` / `END_AUDIT_JSON` block. This avoids double-counting a repeated Codex final answer.
- Require version 1, `complete=true`, contiguous command sequence numbers, and all 11 task records. Missing or malformed ledgers make process-level metrics null, not zero.
- Every command entry counts once. Repeated executions with different sequence numbers count separately.
- A single process serving multiple tasks counts once globally and once in each relevant task's coverage.
- Nested calculation processes must have their own ledger entries.

All these metrics carry the `reported_` prefix. They are mechanically countable claims from the report, not complete native telemetry.

Definitions:

| Metric | Counting rule |
|---|---|
| `reported_cx_calls` | Ledger rows whose normalized executable basename is `cx` |
| `reported_cx_eval_calls` | cx rows other than help, registry discovery, version, or doctor |
| `reported_cx_failed_known` | cx rows with a nonzero recorded exit or a nonempty error id |
| `reported_cx_outcome_unknown` | cx rows with null exit and no error id |
| `reported_cx_failed` | Known failures if no outcomes are unknown; otherwise null |
| `reported_cx_syntax_failures` | Failed cx rows with an id in the fixed set below |
| `reported_cx_help` | cx rows with `--help` or `-h` before `--`, or initial `help` |
| `reported_cx_show` | cx rows with initial `commands show` |
| `reported_cx_search` | cx rows with initial `commands search` |
| `reported_cx_list` | cx rows with initial `commands list` |
| `reported_cx_expected_refusals` | `complex-result` rows attributed only to task 10 or 11 |
| `reported_cx_task_ids` | Union of task ids on cx evaluation rows marked `compute` |
| `reported_cx_primary_tasks` | Tasks naming cx as the primary tool and referencing a cx computation |
| `reported_first_compute_tool` | Tool on the first ledger row marked `compute`, or `none` |

The syntax-failure set is:

```text
syntax-error
unknown-word
invalid-short-option
extra-argument
stack-underflow
```

This is a reproducible proxy for failed syntax guesses. It does not detect successful guesses or the agent's private uncertainty. Keep other failures separate rather than claiming every error is a syntax problem.

Expected refusals are included in total failures and also reported separately. Repeating the same expected refusal still consumes time and counts again. They are not automatically usability defects.

A successful search that returns "No matches." is a lookup, not a failed process.

Audit primary-tool attribution and task links against the answers. A tool used only to verify an answer does not become the primary tool. Help-only exploration does not count as choosing cx for calculation.

For Codex, corroborate ledger entries against native command text and output. Resolve or mark discrepancies; do not silently overwrite one source with the other. For Claude and agy, the saved formats do not permit the same verification. Publish reported and corroborated results separately.

This design does **not** claim complete native process-level friction measurement across all three CLIs. Achieving that would require a separately validated transcript or process-capture change. Do not introduce an untested logging flag or an intercepting cx wrapper into the primary experiment.

### Tokens

Preserve CLI-specific raw fields:

- Claude: `input_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`, `output_tokens`, and nested thinking tokens. Effective input is the sum of the first three when all are present. Do not add nested thinking tokens to output again.
- agy: preserve `input_tokens`, `cache_read_tokens`, `output_tokens`, `thinking_tokens`, and `total_tokens` separately. In the r2 files, `total_tokens = input_tokens + output_tokens`. Do not add thinking or cache tokens to that total without an independently verified provider definition.
- Codex: the first standalone integer after a standalone `tokens used` line is `codex_reported_tokens`. It is not labeled input tokens or split into fabricated input/output components.

Keep cost and turn counts only where supplied. Do not compare agy's `num_turns=1` with Claude's tool-interaction count as though they mean the same thing.

Compare token and time changes within the same model and CLI. Publish medians, individual paired differences, and timeout counts. Do not make a single cross-provider token-efficiency total.

### Reporting missing evidence

Always publish ledger coverage out of the 18 scheduled runs per mode.

For uptake, show:

- Known reported cx users.
- Known reported nonusers.
- Unknowns.
- The corresponding minimum and maximum uptake fractions if every unknown were respectively a nonuser or a user.

A timeout without a complete ledger is unknown for process-level metrics. Absence of a cx string in an incomplete report is not nonuse.

## Preference outcomes and progress criteria

Primary preference endpoint:

```text
At least one task-associated cx evaluation marked compute in available mode.
```

Also report:

- First calculation tool.
- Number and identity of tasks attempted through cx.
- Number completed with cx as the primary tool.
- Verification-only use.
- Help-only exploration.
- Fallback on tasks 10 and 11.
- Continued use after the first cx error.

The unit for the primary uptake rate is the run, not the command. Do not let one enthusiastic model's many calls dominate the result.

Predeclare these practical targets:

1. At least 12 of 18 `available` runs report choosing cx for a calculation, including at least two configurations from each CLI family.
2. Across `available`, cx supplies at least half of the 162 supported-task answers, with valid task attribution.
3. Supported-task correctness in `available` is no lower than `free` in aggregate; publish every paired model result.
4. No confirmed silent wrong cx result occurs on the submitted valid programs.
5. Among cx users, the median reported syntax failures is at most 1 per run.
6. For paired runs that solve all nine supported tasks, median time and the CLI's available token measure in `available` are each at most 1.25 times `free`.

Meeting these targets is evidence of useful adoption after disclosure, not a statistical proof of universal preference. If uptake is high but completion is low, the result is curiosity rather than dependable adoption.

Nonzero corroborated `hidden` use across more than one CLI family is additional progress on discovery. A large `available` versus `hidden` gap identifies presence and discovery as the next constraint.

Publish the 18 paired rows and report by CLI family. These configurations are correlated and are not 18 independent samples from all possible agents. Do not claim statistical significance from this single round.

## Execution checklist

Before launching paid runs:

1. Run every Giac check above and save its transcript.
2. Repeat the cx reference programs on the post-#66 binary.
3. Record executable versions/hashes, resolved model identities where exposed, task-file hash, CLI configuration, and relevant Python package versions.
4. Verify all four mode prompts and PATH states.
5. Confirm that the 11 task lines match the frozen keys.
6. Check the proposed scripts in a normal execution environment. They were not run end to end during this read-only design task.

After each group:

```powershell
./benchmark/summarize-friction.ps1 benchmark/runs/r3-hard-available |
  Export-Csv benchmark/runs/r3-hard-available/friction.csv -NoTypeInformation
```

Use the appropriate mode directory. The original `summarize.ps1` remains the legacy summary; use the new script's raw token fields for r3 interpretation.

The runner uses a 900-second timeout with one-second polling for `hard`; process termination can add a small delay. This caps the local CLI process tree, not a guarantee that a remote provider immediately stops all backend work.
