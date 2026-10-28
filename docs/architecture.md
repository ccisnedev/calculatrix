# Architecture

How the code is organized today, and where it is going. What the language
and each package do is specified elsewhere; this document says where things
live and how they depend on each other.

## Packages

| Directory | Package | Role |
|---|---|---|
| `code/core` | `calculatrix` | The engine and the source of truth: values, both notations, the vocabulary, errors and display text. Pure Dart, no runtime dependencies. Spec: `spec/calculatrix_core.md`, `spec/calculatrix_mathematics.md`. |
| `code/cli` | `calculatrix_cli` | `cx`, the command line, declared on `modular_cli_sdk` and `cli_router`. Spec: `spec/calculatrix_cli.md`. |
| `code/app` | `calculatrix_app` | The Flutter calculator (Android, Windows, web). |

`code/design` holds the logo. `code/api`, `code/db` and `code/infra` are
empty placeholders. `benchmark/` (at the root) holds the agent benchmark
described in `mission.md`.

The app and the CLI depend on core (`path: ../core`) and never duplicate
its math: they parse their own input surface (keys, arguments), call core,
and present what it returns. Values, exactness and error ids are the same
in every consumer; only presentation may differ. Core depends on neither.

## Core

Everything is exported from `code/core/lib/calculatrix.dart`; the sources are
under `lib/src/`. The table in `spec/calculatrix_core.md`, section "Package
structure and public API", lists every library. Where to look:

- **Values** (`matrix/matrix.dart`). Every value is an immutable `Matrix`:
  a scalar is 1x1, a vector n x 1, a complex number a 2x2 real block. A
  matrix is exact (`BigInt` rationals, `exact/`) or approximate (doubles)
  as a whole. Exact arithmetic, exact linear algebra and exact roots, with
  the digit limit, live in `exact/`; tolerances of the approximate path in
  `numeric/numeric_policy.dart`.
- **RPN machine.** `rpn/rpn_engine.dart` is the stack; `machine/` holds
  `CalculatrixMachine`, which runs typed commands, macros and programs,
  and leaves the stack untouched when a command fails.
- **Entry points and infix** (`evaluation/`). `Calculatrix` evaluates RPN
  and infix; infix compiles (shunting-yard) to the same commands RPN runs,
  so each operation has one implementation. Literal parsing is in
  `literals.dart`.
- **Registry** (`registry/command_registry.dart`). The whole vocabulary:
  names, aliases, arity, help text, examples, and the command each word
  builds. RPN resolves words through it; `cx commands` and the "did you
  mean" suggestions read it.
- **Name table** (`names/name_table.dart`). Names and constants.
- **Errors** (`errors/errors.dart`). `CalculatrixError` and its
  subclasses, each with a stable `CalculatrixErrorId`.
- **Formatter** (`matrix/matrix_display_formatter.dart`). Display text
  shared by the app and the CLI.
- **Session** (`session/calculatrix_session.dart`). The keypad session
  the app drives: drafts, stack and memory.

## App

The app has one persistent shell, `RPN`, over the committed stack. `Infix`
and `Matrix` are editors invoked over a pre-stack draft, which is never
labeled as a stack register; the keypad and the module bar are fixed. The
model is `adr/0003-honest-rpn-shell-and-invoked-editors.md`.

The code is in `code/app/lib/modules/calc/`: `controller.dart` (state, over
a core `CalculatrixSession`), `matrix_editor_draft.dart` (the matrix
editor's draft) and `view.dart` (the widgets).

## Testing

- Test-driven: a behavior change starts with a failing test.
- Core: unit tests under `code/core/test/`, one directory per library.
  Every exact word is also tested against Giac
  (`test/exact/giac_differential_test.dart`): Giac is a test oracle only,
  never linked or shipped, and expectations come from mathematics; see
  `adr/0004-pure-dart-engine-and-clean-room.md`. CI runs them on Linux with
  Giac installed and fails if it is missing; elsewhere they skip.
- CLI: tests under `code/cli/test/`, including the benchmark trap set.
- App: controller and editor-draft unit tests, widget tests for the shell
  contracts, and an integration test under `code/app/integration_test/`.

## Releases

Each package has its own version and its own tags: `vX.Y.Z` for the app,
`cli-vX.Y.Z` for the CLI (`adr/0002-versioning-and-changelog-policy.md`).
Release workflows are in `.github/workflows/`.

## Planned

The stages and their order are in `roadmap.md`; the language design is in
`spec/language-decisions.md`. In brief:

- **Language implementation.** A compiler that checks a program (names,
  arity, types) before it runs and reports line and column, and an
  interpreter for the versioned language spec. Infix becomes a translation
  to RPN.
- **Documents.** `cx` runs the `calculatrix` code blocks of a Markdown
  file.
- **Editor tooling.** A language server on the compiler, a VS Code
  extension, a formatter and a linter.
- **Embeddable engine.** The host-neutral API of
  `spec/engine-api-contract.md`, available outside Dart through a C
  interface and WASM.
- **Symbolic computation.** A matrix-first CAS, in pure Dart inside the
  engine, checked against an independent system.
