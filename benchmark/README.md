# Benchmark

The benchmark of `docs/mission.md`: AI agents solve two task sets, with
`cx` or with whatever they normally use, and are graded against answer
keys verified with Giac.

| File | Content |
|---|---|
| `tasks-basic.txt` | The basic set: everyday scalar and matrix computations. |
| `tasks-traps.txt` | The trap set: tasks where floating point or a common slip gives a wrong answer without any error. |
| `answers.md` | The answer keys of both sets, and what `cx` gives on each trap. |
| `trap-set.json` | Each trap as a `cx` program with the output `cx` must give. `code/cli/test/trap_set_test.dart` runs it with the CLI tests. |
| `tasks-hard.txt` | The hard set of round r3: eleven exact tasks, nine that `cx` solves and two it refuses with `complex-result`. |
| `r3-design.md` | The design of round r3: modes, prompts, keys, grading and metrics. |
| `r3-giac.txt` | The Giac transcript that verifies the r3 keys. |
| `run-trial.ps1` | Runs a set on Claude, Codex and Antigravity models, in `cx` mode or free mode; the hard set adds the `available` and `hidden` modes. |
| `summarize.ps1` | One row per run: time, exit code, tokens and cost. `run-trial.ps1` calls it at the end. |
| `summarize-friction.ps1` | One row per hard-set run: time, raw tokens, and the command ledger each agent reports. `run-trial.ps1` calls it for the hard set. |

## Running a trial

```powershell
./benchmark/run-trial.ps1 -Round r2 -Tasks traps -Mode cx
./benchmark/run-trial.ps1 -Round r2 -Tasks traps -Mode free
```

- `cx` mode puts `cx` on the `PATH` and tells the agent to use it. Free
  mode removes every `calculatrix` entry from the `PATH` and lets the agent
  choose its own method.
- `-Only claude-opus,codex-gpt-6-sol` limits the run to some models;
  `-Parallel` sets how many run at once (6 by default). Each run is
  stopped after 15 minutes.
- Each run writes its log to `runs/<round>-<tasks>-<mode>/<run>.txt`, and
  its working directory next to it; git ignores `runs/`.
- The prompt is in Spanish, as in the first trial, so that results stay
  comparable across rounds. It asks for the commands run, the first step
  and why, the final answers and what was confusing about `cx`.

The CLIs `claude`, `codex` and `agy` must be installed and signed in.
Grading is manual, against `answers.md`: for a trap, the exact value must
be the answer the agent commits to, not a remark next to a float.

Round r3 follows `r3-design.md` instead: an English prompt, four modes,
a working directory outside the repository, and a command ledger in JSON.

```powershell
./benchmark/run-trial.ps1 -Round r3 -Tasks hard -Mode available -Only claude-haiku,codex-gpt-6-astra
```

## Results so far

The first trial (PR #53, `cx` 0.8.3, before exact arithmetic) gave 88%
and 81% on the trap set in `cx` mode, in two rounds of 17 and 15 graded
runs, while agents in free mode made one error. Every wrong answer came
from traps 1, 4, 5 and 6, where `cx` returned a float without any error.
Since `cx` 0.14.0 the trap set passes 8 of 8 through `cx` itself (issue
#54, `answers.md`).

Round r3 (`cx` 0.15.0, 18 configurations, 4 modes, 72 runs, no timeouts;
graded blind against the keys of `r3-design.md`):

| Mode | Correct (of 198) | Supported tasks 1-9 (of 162) | 11 of 11 | Runs computing with `cx` | Median seconds |
|---|---:|---:|---:|---:|---:|
| `available` | 194 | 158 | 14 | 2 of 18 | 86 |
| `hidden` | 192 | 156 | 14 | 0 of 18 | 69 |
| `free` | 185 (194 valid) | 151 (158 valid) | 15 | 0 of 18 | 80 |
| `cx` | 197 | 161 | 17 | 16 of 18 | 163 |

- One `free` run (Antigravity gpt-oss) failed before starting, on a network
  error; its labeled rerun scored 9 of 11, which gives the valid-run figures.
- In `cx` mode the only wrong answer came from the one run that never
  called `cx`. Agents that used `cx` made no wrong claims, and on tasks 10
  and 11 every one of them read `complex-result` as a limit of `cx` and
  gave the complex answer itself.
- Correctness is close to the ceiling in every mode, so the gap is
  preference, not accuracy: told that `cx` exists, 2 of 18 agents chose it
  (target: 12), and none found it on their own. In `cx` mode a run took
  about twice as long as the same model in free mode.
- The wrong answers outside `cx` were misread inputs, an RREF left
  unreduced (5 runs), a wrong dot product, a rank of 2 and a miscomputed
  decimal. Per-run rows are in `runs/r3-hard-<mode>/friction.csv`.
