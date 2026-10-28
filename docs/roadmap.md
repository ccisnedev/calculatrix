# Roadmap

Stages toward the mission (`mission.md`). The order says what blocks
what, not a calendar; stages may overlap. The work in progress is in
`runbook.md`. Each package keeps its own version; stages are not tied to
version numbers.

## Where we are

- `calculatrix` (core): exact RPN engine on matrices, with rationals,
  big integers, complex numbers as 2×2 blocks and matrix functions.
- `cx`: the CLI over the core, with help, discovery and stable error
  ids. 8 of 8 on the benchmark trap set.
- The calculator app (Android, Windows, web).
- The language is designed in `spec/language-decisions.md`; nothing of
  it (variables, functions, control flow, infix as translation) is
  implemented yet.

## Stages

| # | Stage | Delivers | Done when |
|---|---|---|---|
| 0 | Order | One mission, roadmap and runbook; specs that describe what exists; issues mapped to stages. | Runbook phase 1 is ticked. |
| 1 | Language specification | The versioned language spec (0.1): lexical structure, grammar of both notations, types, names and scope, functions, control flow, errors, limits, the infix→RPN translation. A conformance suite format. | Every open question is settled, including what `%` means (#86), and the spec has worked programs (quadratic formula, factorial, Newton with a convergence test, error trapping). |
| 2 | Reference engine | First the cleanup of the core and the app (#96, #97, #98). Then the Dart engine runs spec 0.1: a compiler that checks programs before running (names, arity, types) with line and column, an interpreter, evaluation limits (#48). `cx` runs one line, a file or standard input. | The Dart engine passes the conformance suite. |
| 3 | Documents | `cx` runs the `calculatrix` blocks of a Markdown file and shows or writes their results. | A Markdown document with several blocks runs end to end, with errors pointing at block and line. |
| 4 | Editor tooling | A language server built on the compiler; a VS Code extension (highlighting, diagnostics, hover from the command registry, run a file or a block); a formatter and a linter. | Writing and running a program in VS Code needs no other tool. |
| 5 | Numeric completeness | Complex results (#64) and their notation (#78), the open numeric issues (#14, #16, #71, #87, #88, #89, #91). | Complex tasks of the benchmark agree with the reference, and no open issue is a silent wrong result. |
| 6 | Presence | The skill (#47), the MCP server (#44), installers, an instruction-file snippet; benchmark r4 with native evidence (#76, #77), published per release. | Agents choose calculatrix without being asked. |
| 7 | Embeddable engine | The engine API (`spec/engine-api-contract.md`) available outside Dart: a native library with a C interface and WASM, and bindings for other languages. | A program runs the same from at least two host languages besides Dart. |
| 8 | Symbolic computation | A matrix-first CAS in pure Dart (MIT): symbols in matrices, simplification, solving. Checked against an independent system. | To be defined with O6. |

The app follows the engine: it gains each language feature after the
CLI has it.

## 1.0

To be defined. A candidate: language spec 1.0 with a compatibility
promise, an engine that passes its conformance suite, and `cx` and the
editor tooling on top.
