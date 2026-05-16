# Calculatrix CLI Specification

Status: Draft
Owner: Calculatrix maintainers
CLI package name: `calculatrix_cli`
Core dependency: `calculatrix`

## 1. Purpose

`calculatrix_cli` is the command-line consumer of the `calculatrix` core package.
Its goal is to expose matrix and RPN capabilities for shell workflows,
automation, and scripting.

## 2. Non-goals

1. Re-implementing matrix or RPN logic already in `calculatrix`
2. UI-specific concerns from Flutter
3. Persistent data storage in initial version

## 3. Functional Scope (v0)

1. Evaluate matrix operations from command input
2. Evaluate RPN expressions from command input
3. Return machine-friendly output (plain text and JSON modes)
4. Return deterministic non-zero exit codes for domain errors

## 4. Command Surface (initial proposal)

```text
calculatrix_cli matrix add --a "[[1,2],[3,4]]" --b "[[5,6],[7,8]]"
calculatrix_cli matrix mul --a "[[1,2],[3,4]]" --b "[[5],[6]]"
calculatrix_cli matrix transpose --a "[[1,2,3],[4,5,6]]"

calculatrix_cli rpn eval "3 4 + 2 *"
calculatrix_cli rpn eval "[[1,2],[3,4]] [[5,6],[7,8]] *"
```

## 5. Input/Output Rules

1. Matrix literals use bracket notation: `[[1,2],[3,4]]`
2. Scalars are mapped to `1x1` matrices internally
3. Default output is compact text
4. `--json` outputs structured JSON

Example JSON output:

```json
{
  "ok": true,
  "result": [[19.0, 22.0], [43.0, 50.0]],
  "shape": [2, 2]
}
```

## 6. Error Contract

Errors from `calculatrix` are mapped to CLI error codes and messages.

Initial mapping:

1. Invalid matrix shape -> exit code 2
2. Dimension mismatch -> exit code 3
3. RPN stack underflow -> exit code 4
4. Parse/input error -> exit code 5
5. Unknown internal error -> exit code 1

## 7. Architecture Constraints

1. `calculatrix_cli` depends on `calculatrix`
2. No duplicated math algorithms in CLI project
3. CLI adapters only: parse args, call core, format output

## 8. Test Strategy

1. Unit tests for argument parsing and output formatting
2. Integration tests for command invocations against known vectors
3. Golden tests for JSON output consistency

## 9. Future Extensions

1. Interactive REPL mode
2. Stack inspection mode for RPN workflows
3. Piping support (`stdin` matrix/RPN payloads)
4. Backend parity mode for API contract testing
