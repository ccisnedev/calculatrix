# Mission

**calculatrix is an open ecosystem for matrix computation, numeric and
symbolic: a formal language, engines that run it anywhere, and the tools
to write, check and run its programs.** Its users are agents, human or
AI. When an agent has a calculation to make, calculatrix is what it
reaches for without being told to, the way a person reaches for a
scientific calculator.

## What it is

- **A language with two notations and one meaning.** A high-level infix
  notation, close to Julia or Dart, for people, agents and larger
  programs. A stack notation (RPN) that is the complete language and the
  one engines run. Infix translates to RPN by normative rules. The
  language has a versioned specification in this repository, and it
  evolves by new versions of that specification.
- **Matrices first, numeric and symbolic.** Every value is a matrix: a
  scalar is 1×1, a complex number is a 2×2 block. Engines compute
  exactly with numbers and symbolically with expressions (a CAS), and
  in both cases the matrix is the unit of computation.
- **Embeddable engines.** An engine is a library that runs the language,
  on the SQLite model: small, self-contained, callable from any host
  language. Every engine gives the same result, error or limit for the
  same program. The reference engine is the Dart package `calculatrix`.
- **Tools.**
  - `cx`, the command line: runs one line, a file, or the `calculatrix`
    code blocks of a Markdown document.
  - A compiler that checks a program before it runs (names, arity,
    types) and reports errors with line and column.
  - Editor support: a language server, a VS Code extension, a linter, a
    formatter.
  - The calculator app for people.
  - Agent integrations: a skill and an MCP server.

## Where we compete

Today an AI agent computes with Python and NumPy, or SymPy for symbolic
work. calculatrix does not try to beat them on speed or breadth. It
competes on:

- **Trust.** A result is right, or the engine says why it cannot give
  one. It never returns a wrong result silently.
- **Usability.** An agent with no prior knowledge learns the language
  from the tools themselves, and solves a task in as few steps and
  tokens as it would with NumPy.

## Principles

1. **Never a silent wrong result.** Exact arithmetic wherever the exact
   value exists. An approximate result says so. A failed precondition
   is an error with a stable id.
2. **A closed language.** A program cannot touch files, the network or
   the system. The host reads files and writes output; the language
   only computes. A host can therefore run any program without asking
   for approval.
3. **The specification is the source of truth.** Engines and tools
   follow it, a conformance suite checks them, and a change of meaning
   is a new language version.
4. **Clarity first.** Words have full names (`determinant`, `inverse`).
   Aliases help those who already know them, but the specification, the
   translation and the tools use the full names.
5. **A stable contract.** Error ids, exit codes and machine-readable
   output are versioned and tested. A breaking change is a new major
   version.
6. **Discovery from the tools.** Help, error messages and the editor
   teach the next step. A feature an agent cannot discover is not
   finished.

## How we measure

- **Conformance.** Every engine passes the specification's test suite.
- **Benchmark.** Real agents (Claude Code, Codex, Antigravity) solve
  fixed task sets with and without calculatrix, graded blind against
  keys verified with an independent system. The task sets, keys and
  scripts live in `benchmark/`. The metric that matters most: **with
  calculatrix available but not requested, does the agent choose it?**
