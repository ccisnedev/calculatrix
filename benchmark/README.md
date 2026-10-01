# Benchmark

The benchmark of `docs/mission.md`: AI agents solve two task sets, with
`cx` or with whatever they normally use, and are graded against answer
keys verified with Giac.

| File | Content |
|---|---|
| `tasks-basic.txt` | The basic set: everyday scalar and matrix computations. |
| `tasks-traps.txt` | The trap set: tasks where floating point or a common slip gives a wrong answer without any error. |
| `answers.md` | The answer keys of both sets, and what `cx` gives on each trap. |
| `trap-set.json` | Each trap as a `cx` program with the output `cx` must give. `code/cli/test/trap_set_test.dart` runs it in CI. |
| `run-trial.ps1` | Runs a set on Claude, Codex and Antigravity models, in `cx` mode or free mode. |
| `summarize.ps1` | One row per run: time, exit code, tokens and cost. `run-trial.ps1` calls it at the end. |

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

## Results so far

The first trial (PR #53, `cx` 0.8.3, before exact arithmetic) gave 88%
and 81% on the trap set in `cx` mode, in two rounds of 17 and 15 graded
runs, while agents in free mode made one error. Every wrong answer came
from traps 1, 4, 5 and 6, where `cx` returned a float without any error.
Since `cx` 0.14.0 the trap set passes 8 of 8 through `cx` itself (issue
#54, `answers.md`).
