# Mission

**calculatrix (`cx`) is to be the best computation tool for agents, human
or AI.** When an agent has a calculation to make, `cx` is the tool it
reaches for without being told to, the way a person reaches for a
scientific calculator. This is the goal of the repository, however many
years it takes.

## Where we compete

The tool an AI agent uses today is Python with NumPy. Models know it from
training, it is fast on large data and its ecosystem is huge. calculatrix
does not try to beat it on speed or breadth. It competes on two things:

- **Trust.** A result from `cx` is right, or `cx` says why it cannot give
  one. It never returns a wrong result silently.
- **Usability.** An agent with no prior knowledge of `cx` finds out how to
  use it from `cx` itself, and solves a task in as few steps and tokens as
  it would with NumPy.

## Principles

1. **Never a silent wrong result.** Exact arithmetic wherever the exact
   value exists. When a result is approximate, the output says so. When a
   precondition fails, the error names it with a stable id.
2. **A closed language.** A program cannot touch files, the network or the
   system. An agent host can therefore allow `cx` without asking for
   approval on every call, which no general-purpose interpreter allows.
3. **A verifiable program.** The input is one short line that a person can
   read, check and run again.
4. **A stable contract.** Error ids, exit codes and the `--json` shapes are
   versioned and tested. A breaking change is a new major version.
5. **Discovery from the tool.** `--help`, `cx help`, `cx commands` and the
   error messages teach the next step. A feature an agent cannot discover
   through the CLI is not finished.
6. **One engine.** The CLI, the app, the MCP server, the skill and any HTTP
   API share the core package and its contract.

## How we measure

A benchmark of real agents (Claude Code, Codex and Antigravity, across
their models) solving fixed task sets twice: once told to use `cx`, once
free to use whatever they normally use.

- **Basic set**: everyday scalar and matrix computations. Measures time,
  tokens, commands, failed commands and correctness.
- **Trap set**: tasks where floating point or a common slip gives a wrong
  answer without any error, such as `3^40`, `(10^16 + 1) - 10^16`,
  `0.1 + 0.2 - 0.3` or the inverse of a Hilbert matrix. Answer keys are
  verified with Giac.

The task sets, answer keys and scripts live in `benchmark/`.

The metric that matters most: **with `cx` installed and mentioned in the
agent's instructions, but not requested for the task, does the agent
choose `cx` on its own?**

## Stages

| Stage | Work | Done when |
|---|---|---|
| 0. Frictions | Remove what slows agents down on first contact: root help, explanatory errors, useful suggestions. Move the benchmark into the repository. | Agents match their NumPy time and tokens on the basic set. |
| 1. Trust | Exact arithmetic. A formatter that never shows float noise. The whole final stack in the output. Complex results with their own error ids. Differential tests against Giac in CI. | 8 of 8 on the trap set, and no silent wrong result anywhere. |
| 2. Usability | Infix with functions and constants. `solve`. Root `--help` and `--version` as users expect them. The app for people. | Failed commands per task close to zero. |
| 3. Presence | The skill, the MCP server in MCP registries, plugins for coding agents, one-command installers on every platform, and a snippet for agent instruction files. | Agents choose `cx` without being asked. |
| 4. Public evidence | Benchmark results per model, published with every release, and documentation rich in examples. | The comparison with NumPy is public and reproducible. |
| 5. Training data | Public docs, examples and solved questions, so that future models know `cx` the way they know NumPy. | A new model uses `cx` correctly without reading its help. |

Stages overlap. The order says what blocks what, not a calendar.
