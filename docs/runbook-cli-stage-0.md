# Runbook: CLI Stage 0

Stage 0 turns `code/cli` into a real, installable CLI named `calculatrix` (alias
`cx`), built on `modular_cli_sdk`, so it can be used every day (dogfood) before
the shared command line lands in core and in the app.

This file is for discussion first. Nothing in `code/cli` changed until the
"Open questions" section was settled; since 2026-09-24 every question is
closed. Update it as work lands: tick the box, add
the PR, and append a line to the progress log.

Parent plan: `docs/runbook-1.0.0.md`. This stage is the first slice of Stage 9
("Kernel Seam and Command Registry") in `docs/roadmap.md`.

## Goal

```text
cx                                   banner (later: a REPL with a live stack)
cx eval rpn '-1 2 +'                 prints the stack after running the program
cx '-1 2 +'                          shortcut for `cx eval rpn`
cx eval infix '-1+2'                 prints the result
cx eval rpn --json -f prog.rpn       options after the route, before the program
cx commands show power               the encyclopedia entry of a command
cx version
cx doctor
cx upgrade --plan | --apply
```

The full design is in `docs/spec/calculatrix_cli.md` (D22).

The CLI, the app, and the future REPL run the same thing: an RPN command line
that is parsed into objects and then executed one object at a time against the
stack. The app is that with a keypad; the REPL is that without one.

## Decisions already made

| # | Decision | Source |
|---|---|---|
| D1 | The program is `calculatrix`, with `cx` as its alias. | User, 2026-09-23 |
| D2 | The CLI uses `modular_cli_sdk` and `cli_router`, structured like `macss/code/cli`. | User, 2026-09-23 |
| D3 | Every route of the domain (`eval`, `commands`) and every maintenance route that changes nothing (`version`, `doctor`, `help`) is a query. `upgrade` and `uninstall` change the installation, so they are commands with `--plan` and `--apply` (D26). Amended 2026-09-24. | User, 2026-09-23 and 2026-09-24 |
| D4 | Bare `cx` / `calculatrix` prints a logo and a short presentation. A Julia-style REPL replaces it in a later stage. | User, 2026-09-23 |
| D5 | Command names are plain ASCII words that are easy to type. No `→`. When the word is short, use the whole word (`vector`, `power`). | User, 2026-09-23 |
| D6 | Matrix literals accept spaces as separators, in RPN and in infix: `[[0 -1] [1 0]]`. | User, 2026-09-23 |
| D7 | One PR per step. | User, 2026-09-23 |
| D8 | Negative numbers and quoted expressions must work without `--`. Fixed upstream in `cli_router` (issue ccisnedev/cli_router#4), not worked around in this repo. | User, 2026-09-23 |
| D9 | The CLI is published and installed the way `macss` is: release binaries, an installer, `cx upgrade`. | User, 2026-09-23 |
| D10 | `vector` always takes the element count, like the HP. | User, Q1 |
| D11 | Everything is a matrix. A vector is a **column** matrix (n x 1). | User, Q2 |
| D12 | Follow the HP 50g style by default (stack display, behavior), unless the user decides a better option for a specific point. | User, Q3 |
| D13 | Spaces everywhere: matrices are read and displayed as `[[0 -1] [1 0]]`, in the CLI and in the app. | User, Q4 |
| D14 | Commands have aliases. The registry needs an alias mechanism; `^` is an alias of the power command. | User, Q5 |
| D15 | `upgrade` and `uninstall` belong in a package of the `modular_cli_sdk` ecosystem, because every CLI needs them. Corrected 2026-09-24: they are commands, not queries (D26). | User, Q6 and 2026-09-24 |
| D16 | Command names that are not a single word use the cmdlet pattern `<verb>-<subject>`. | User, Q8 |
| D17 | There is no `matrix` command: everything is a matrix. Two commands build matrices: `append-rows` places B below A (same number of columns) and `append-cols` places B to the right of A (same number of rows). Renamed from `join-rows` / `join-cols` on 2026-09-24. | User, Q8 |
| D18 | `exp` is e^x, as on the HP. x^y is `power`, with aliases `pwr` and `^`. | User, Q9 |
| D19 | Each product in the repository has its own tag prefix. The CLI uses immutable `cli-vX.Y.Z` tags; the app keeps `vX.Y.Z`. `cx upgrade` filters releases by prefix and never uses `releases/latest`. | User, Q7 |
| D20 | `upgrade` and `uninstall` come from a new ecosystem package, `modular_cli_installer`, shared by every CLI (`macss`, `docmd`, `cx`). Replaced on 2026-09-24 by D33: there is no such package. | User, Q10 |
| D21 | Evaluation is its own module: `cx eval rpn <program>` and `cx eval infix <expression>`, with `--file` or `--stdin` as the other sources. The shortcut `cx <program>` is RPN only, takes one argument and no options. The global module holds only maintenance (`version`, `upgrade`, `uninstall`, `doctor`, `help`); `help`, `--help` and `-h` are provided by the SDK. Revised 2026-09-24; replaces `eval` in the global module with `--infix`. | User, 2026-09-24 |
| D22 | The design is specified in `docs/spec/calculatrix_cli.md`: modules, grammar rules G1 to G12, route catalog, encyclopedia, declarative model, the upstream releases it needs and the closed decisions R1 to R17 of its section 14. That file supersedes the catalog below. | User, 2026-09-24 |
| D23 | The CLI never guesses: an ambiguous invocation is rejected, never reinterpreted. No fallbacks, no undeclared defaults. | User, 2026-09-23 |
| D24 | The shortcut and the grammar rest on `cli_router` 0.2.0 (trie resolution, typed lossless option schema, `onReject`) and `modular_cli_sdk` 0.6.0 (contracts with typed positionals and constraints, `shortcut`, help after resolution). Both are breaking releases with migration notes for the seven known consumers. | User, 2026-09-24 |
| D25 | `power` computes `B^Y = exp(Y · log B)` on matrices, with the exponent a matrix too (`e πi ^` gives -1). The cases and their errors are the table in "Semantics of `power`" below. `X exp` equals `e X ^`, and `exp` stays. Closes Q5. | User, 2026-09-24 (R13) |
| D26 | `upgrade` and `uninstall` are SDK commands: `--plan` shows the steps, `--apply` performs them, neither is a default, and there is no interactive prompt. They come from `InstallationPlugin` (D33); `cx` registers it with its repository, tag prefix, executable, alias and asset names. There is no `cx install`: the release script installs. | User, 2026-09-24 (R1, R11) |
| D27 | The grammar is strict and POSIX: route, then options, then operands; flags are presence only (no `=value`, no negation); short options stand alone (no clusters, no attached values); stdin is read only with `--stdin`; the shortcut takes no options, not even globals; an empty program is error 7. Every rejected form can become valid later without breaking anyone. Spec rules G1 to G12. | User, 2026-09-24 (R2 to R7) |
| D28 | Exit codes: `0` ok, `64` usage, `7` validation, `65` domain error (`ExitCode.dataError`, new in the SDK), `78` installation error found by `doctor` (`ExitCode.configError`, new in the SDK). `-q/--quiet` stays a global of the SDK and suppresses only progress messages. | User, 2026-09-24 (R9, R10) |
| D29 | `append-cols` and `append-rows` have no aliases. Each registry entry has a list of search terms (`hcat`, `vcat`, `concatenate`), used by `cx commands search` and by the "did you mean" of `unknown-word`. | User, 2026-09-24 (R12) |
| D30 | JSON of `eval` is `{"stack": [...]}`, level 1 last; a 1x1 matrix is a number, any other matrix an array of rows. Errors are `{"error": {"id", "message", "token", "position"}}`, with `position` 1-based. | User, 2026-09-24 (R16) |
| D31 | `cx doctor` checks the binary on `PATH`, the alias `cx` and the newest `cli-v*` release. States ok, warning, error; a newer release and a failed lookup are warnings, printed, never skipped; exit 78 when any check is an error. The checks are contributions to the extension point `doctor.checks` (D33), and `macss` and `docmd` adopt them. | User, 2026-09-24 (R17) |
| D32 | Not in this stage: `--trace` and `--show-rpn` (recorded in `docs/roadmap.md`, Stage 9). `CliRequest.flags` is removed in `cli_router` 0.2.0, with no deprecation period. | User, 2026-09-24 (R14, R15) |
| D34 | From the Codex review of the design: (1) `power` follows the order of checks of the D25 table, by kinds, never by a numerical commutation test; (2) a matrix base with no real logarithm is `log-undefined` in this stage, and its representation is deferred; (3) `-h`/`--help` wins over `incomplete`, `missingArgument`, `missingRequiredOption` and the contract constraints, and loses to `unknownCommand`, `extraArgument` and the option errors (spec 8.6); (4) a failed step of `upgrade --apply` or `uninstall --apply`, or a failed release lookup, exits `1` (`ExitCode.genericError`) with the id `release-lookup-failed`, `download-failed` or `file-access-denied`; the run stops at that step, reports the steps done, and neither rolls back nor retries (spec section 6). | User, 2026-09-24 |
| D33 | `modular_cli_sdk` gets a plugin system modeled on `modular_api` (`CliPlugin` with a manifest and `setup(host)`; the host registers routes and extension points, nothing else for now). `version`, `doctor`, `upgrade` and `uninstall` are standard plugins inside the SDK (`VersionPlugin`, `DoctorPlugin`, `InstallationPlugin`), like health and openapi in `modular_api`. Every plugin is registered explicitly with `cli.plugin(...)`. `DoctorPlugin` declares `doctor.checks`; `InstallationPlugin` requires it and contributes its checks. No `modular_cli_installer` package, no install plugin. Spec section 8.7. | User, 2026-09-24 (R18) |
| D35 | From the Codex review of the core PR (calculatrix#7): an iterative method of the core (matrix exponential by scaling and squaring, square root, logarithm) that reaches its iteration cap without meeting its tolerance raises the new id `no-convergence` (65), never the unconverged value. Every intermediate result is checked for finiteness (`non-finite`). | Claude, 2026-09-25 |
| D36 | One JSON error shape for every error: `{"error": {"id", "message", "exitCode", ...}}`, `id` in kebab-case (the SDK maps each router rejection kind to one id), extra fields only when they apply (`token`, `position`, `contract`, `details`). `isRetryable` is removed; `CommandException.exitCode` is required. Spec section 6. | User, 2026-09-25 |
| D37 | From the Codex review of the core PR (calculatrix#7): `exp`, `log`, `sqrt` and a non-integer real power are defined on exactly five classes of matrix: a scalar, the complex form `a·I + b·J`, an exactly diagonal matrix, an exactly symmetric matrix (cyclic Jacobi eigendecomposition) and a general 2x2 matrix (closed form `c0·I + c1·A`). Any other matrix raises the new id `unsupported-matrix-function` (65); the core never approximates outside these classes. The only iterative method left is the cyclic Jacobi sweep, whose cap is the source of `no-convergence` (D35). A general `n x n` algorithm is future work. | User, 2026-09-25 |
| D38 | From the Codex review of the core PR (calculatrix#7), rounds 7 and 8: `exp`, `log`, `sqrt` and a non-integer real power declare their precision range. Every nonzero entry of the matrix and every nonzero computed eigenvalue must have a magnitude between `1e-150` and `1e150`; zero entries are allowed. A matrix outside that range raises the new id `matrix-out-of-precision-range` (65), and the message names the offending entry or eigenvalue. Inside the range the result has a normwise relative error (Frobenius) of at most `1e-12`; a single entry that is tiny next to the norm of the result is not guaranteed componentwise. Integer powers are not affected. | User, 2026-09-25 |

## Command catalog (proposal)

Superseded by `docs/spec/calculatrix_cli.md` (D21, D22). Kept as the record of
the first proposal.

### Global module

| Route | What it does |
|---|---|
| `cx` | Logo, version, and the list of modules. |
| `cx version` | Prints the CLI version. `--version` and `-v` map to it. |
| `cx upgrade` | Downloads and installs the latest CLI release. |
| `cx uninstall` | Removes the installed CLI. |
| `cx help` | Provided by the SDK. |

### `rpn` module

| Route | What it does |
|---|---|
| `cx rpn eval '<line>'` | Parses the line, runs it on an empty stack, prints the stack. |
| `cx rpn commands` | Lists the command registry (names, aliases, stack effect). Lands with the core registry, not in the first PR. |

Examples once the core command line exists:

```text
cx rpn eval '2 2 ^ 1 +'                        5
cx rpn eval '[[0 -1] [1 0]] det'               1
cx rpn eval '0 1 2 vector -1 0 2 vector join-cols'
                                               [[0 -1] [1 0]]
```

### `infix` module

| Route | What it does |
|---|---|
| `cx infix eval '<expression>'` | Evaluates an algebraic expression. |

Stage 0 calls the current infix evaluator. Compiling infix into the RPN line
(the long-term design, so both modes share one executor) is a later change in
core.

### What the first PR keeps from today's CLI

Today's `calculatrix_cli` has four modes: `infix`, `rpn`, `command`, `macro`.
The first PR maps `infix` and `rpn` to the new routes. `command` and `macro`
(and the `pick:2`, `zeros:2x3` syntax) fold into `rpn eval` when the core
registry lands. The CLI is not published yet, so this is not a break for
anyone; it is still recorded in `CHANGELOG.md`.

## Command names (proposal)

| Calculatrix | HP 50g | Stack effect |
|---|---|---|
| `vector` | `→ARRY` (vector form) | `x1 ... xn n` gives the n x 1 column `[[x1] ... [xn]]` |
| `append-cols` | none (closest: `COL+`) | `A B` gives `[A B]`; A and B need the same number of rows |
| `append-rows` | none (closest: `ROW+`) | `A B` gives A over B; A and B need the same number of columns |
| `rows` | `ROW→` | `[[...]]` gives `[row1] ... [rown] n` |
| `power`, aliases `pwr`, `^` | `^` | `B Y` gives `B^Y` (D25) |
| `exp` | `EXP` | `X` gives e^X |

Matching is case-insensitive. ASCII spellings of the HP names (`->ARRY`,
`ROW->`) are accepted as aliases for users coming from the HP. A row vector is
`1 2 2 vector transpose`, or the literal `[[1 2]]`. Search terms (D29) are
not aliases: `hcat` finds `append-cols` in `cx commands search`, but it is not
a word of the language.

## Semantics of `power` (D25)

Everything is a matrix (D11), so `power` is defined on matrices:
`B^Y = exp(Y · log B)`, where `log` is the principal matrix logarithm
(`Matrix.log()`) and `exp` the matrix exponential (`Matrix.exp()`). In the
table, "scalar" means a 1x1 matrix, and "complex" means a 2x2 matrix of the
form `[[a -b] [b a]]`, which is `a+bi` with `i = [[0 -1] [1 0]]` (roadmap
Stage 6). Complex matrices commute with each other, so the order of the
product `Y · log B` does not matter for them.

| # | Base B | Exponent Y | Result | Example |
|---|---|---|---|---|
| 1 | scalar | scalar | real power. B < 0 with a non-integer Y gives the complex principal value, consistent with the square root of a negative number | `-4 0.5 ^` gives `[[0 -2] [2 0]]` |
| 2 | scalar > 0 | square matrix | `exp(ln B · Y)` | `e πi ^` gives `[[-1 0] [0 -1]]` |
| 3 | complex, or scalar < 0 | complex | `exp(Y · log B)` | `i i ^` gives `[[0.2079 0] [0 0.2079]]`, which is e^(-π/2) |
| 4 | square | integer scalar | repeated multiplication; a negative integer uses the inverse; a singular B with a negative integer is `singular-matrix` | `[[1 1] [0 1]] 3 ^` gives `[[1 3] [0 1]]` |
| 5 | square | non-integer scalar | `exp(y · log B)`. A base that is not a scalar and not complex, with a real eigenvalue ≤ 0, is `log-undefined` (deferred, see below) | `[[2 0] [0 3]] 0.5 ^` gives `[[1.4142 0] [0 1.7321]]`; `[[1 1] [0 1]] 0.5 ^` gives `[[1 0.5] [0 1]]`, with a base that is not diagonalizable |
| 6 | any other pair with Y not a scalar (order of checks, below) | square, not scalar | `ambiguous-power`: `exp(Y log B)` and `exp(log B · Y)` differ when Y and log B do not commute. Case 3 is the exception | `[[1 1] [0 1]] [[0 1] [1 0]] ^`: `log B` is `[[0 1] [0 0]]`, and the two orders give `[[1 0] [0 2.7183]]` and `[[2.7183 0] [0 1]]` |
| 7 | 0 | scalar | Y > 0 gives 0; `0 0 ^` gives 1; Y < 0 is `non-finite` | `0 -1 ^` |
| 8 | 0, or a singular matrix, where the case needs `log B` | | `log-undefined` | `0 πi ^` |
| 9 | not square | any | `dimension-mismatch` | `[[1 2]] 2 ^` |
| 10 | any | not square | `dimension-mismatch` | `2 [[1 2]] ^`, `[[1 0] [0 1]] [[1 2]] ^` |
| 11 | n x n | m x m, n ≠ m, neither scalar | `dimension-mismatch` | `[[1 0] [0 1]] [[1 0 0] [0 1 0] [0 0 1]] ^` |
| 12 | scalar < 0 | square, not complex, not scalar | `ambiguous-power`: `log B` is complex (2x2) and does not match Y | `-2 [[1 0] [0 2]] ^`: `log -2` is `[[0.6931 -3.1416] [3.1416 0.6931]]`, which does not commute with Y |
| 13 | any | any, when the result overflows | `non-finite` | `10 400 ^` (10^400 exceeds the largest double) |

**Order of the checks.** The first rule that applies decides; the kinds of
B and Y decide, never a numerical test of whether they commute:

1. Dimensions: B is square (case 9), Y is square (case 10), and when neither
   is a scalar both have the same size (case 11). Otherwise
   `dimension-mismatch`.
2. Y is a scalar: cases 1, 4, 5, 7, 8 and 13.
3. Y is not a scalar: B is 0 is `log-undefined` (case 8); B scalar > 0 is
   case 2; B complex or scalar < 0 with Y complex is case 3. Every other pair
   is `ambiguous-power` (cases 6 and 12): `i [[1 0] [0 2]] ^` is
   `ambiguous-power`.

**Deferred: a matrix with no real logarithm.** `[[-1 0] [0 2]] 0.5 ^` has no
real result: the base has a negative eigenvalue and is not of the complex
form. In this stage it is `log-undefined`. A complex number is only
`a·I + b·J`, with `J = [[0 -1] [1 0]]`; how to represent a matrix whose
entries would be complex is to be studied (roadmap, Stage 9). Turning the
error into a value later breaks no one.

All errors exit with `65`. `ambiguous-power`, `log-undefined`,
`no-convergence` (D35), `unsupported-matrix-function` (D37) and
`matrix-out-of-precision-range` (D38) are new ids;
there is no `not-real` error, because the result of case 1 with a negative
base is a complex matrix. `X exp` gives the same value as `e X ^`. The step
S4 turns every row of this table into a core test, which also measures the
precision of `Matrix.log()` on non-diagonal matrices (spec section 11,
risk 5). The examples were checked on 2026-09-24 with Julia's `exp` and
`log` of `LinearAlgebra`, rounded to 4 decimals. A test compares each entry with its expected value within `5e-5`. `Matrix.log()` must compute the principal logarithm of a matrix that is not diagonalizable (the second example of case 5); passing only the diagonal examples is not enough. Every example of this table is in one of the five classes of D37; a base outside them (for example a 3x3 matrix that is neither diagonal nor symmetric) raises `unsupported-matrix-function`.

## Open questions

- [x] **Q1. Does `vector` need the count?** The example on 2026-09-23 was
  `0 -1 2 vector 1 0 vector 2 matrix`: the first `vector` has a count and the
  second does not. With the count (`1 0 2 vector`), `vector` works however deep
  the stack is, like the HP. Without it, `vector` would have to take the whole
  stack. Proposal: always take the count.
- [x] **Q2. Is a vector its own type?** The HP tells `[1 2]` (vector) apart from
  `[[1 2]]` (1x2 matrix). Core only has `Matrix` today. Proposal for Stage 0: a
  vector is a 1xn matrix, and the difference is recorded as a known parity gap.
- [x] **Q3. Output format of `rpn eval`.** Proposal: HP style, level 1 at the
  bottom, spaces inside matrices, the same way the app shows the stack:

  ```text
  2: 5
  1: [[0 -1] [1 0]]
  ```

  `--json` (global option from the SDK) prints the stack as JSON. Amended
  2026-09-24: the shape is `{"stack": [...]}` (D30).
- [x] **Q4. Display format everywhere.** D6 makes spaces the input separator.
  Should `MatrixDisplayFormatter.compact` also print `[[0 -1] [1 0]]` instead of
  `[[0, -1], [1, 0]]`? That changes the app and the CLI tests.
- [x] **Q5. Scope of the power command.** Proposal: real to real power, and a square matrix
  to an integer power. To verify in the AUR: negative base with a non-integer
  exponent (complex result on the HP), and what the HP does with a matrix
  power. Answer: D25. The scope is wider than the proposal: the exponent can
  be a matrix too, and a negative base gives a complex matrix, not an error.
- [x] **Q6. Are `upgrade` and `uninstall` queries too?** D3 says every route is
  a query. In `macss` these two are commands, because they change the system.
  Proposal: follow D3, and have `uninstall` ask for confirmation. Answer
  amended 2026-09-24: they are commands with `--plan` and `--apply`, and
  `--apply` is the confirmation, with no interactive prompt (D26).
- [x] **Q7. Release tags.** See "Publishing" below. Answer: D19.
- [x] **Q8. What does `matrix` take, now that a vector is a column?** On the
  HP, `→ROW` takes row vectors. With column vectors, the natural reading is
  `col1 ... coln n matrix` builds the matrix from columns (the HP has `→COL`
  for that). Options: (a) `matrix` builds from columns; (b) `matrix` builds
  from rows and each row is transposed; (c) two commands, `rows` and
  `columns`, like `→ROW` and `→COL`. With (a), `[[0 -1] [1 0]]` is
  `0 1 2 vector -1 0 2 vector 2 matrix`. Answer: D17, no `matrix` command.
- [x] **Q9. Name of the power command.** On the HP 50g, `EXP` is e^x, not
  power. Calling the power command `exp` would clash with that meaning, and
  with D12. Proposal: `power` (full word, D5) with alias `^`, and keep `exp`
  for e^x.
- [x] **Q10. Name of the ecosystem package for `upgrade` and `uninstall`.**
  It has to handle: the GitHub repository, a tag prefix (Q7), the asset name
  per platform, the install folder, and the alias shim. Proposal:
  `modular_cli_release`. Answer: D20, `modular_cli_installer`, since it
  installs, upgrades, and uninstalls, and it does not publish releases.
  Replaced on 2026-09-24: standard plugins inside the SDK (D33).

## Publishing (dogfood)

The model is `macss`: a release workflow builds the binaries, an installer puts
them in `%LOCALAPPDATA%\calculatrix\bin`, and `cx upgrade` replaces them.

### Constraints found in this repository

1. **Tags collide.** App releases already use `vX.Y.Z` (`v0.7.1` is published
   and is the GitHub "Latest"). The CLI needs its own prefix. Proposal:
   `cli-vX.Y.Z`. This amends ADR 0002 section 8.
2. **App workflows fire on every release.** `android-release.yml` and
   `windows-release.yml` run on `release: published` with no filter, so a CLI
   release would build and upload an Android bundle and a Windows app. Both
   need `if: startsWith(github.event.release.tag_name, 'v')`.
3. **`releases/latest` is ambiguous.** `macss upgrade` asks GitHub for the
   latest release. Here that could be an app release. `cx upgrade` must list
   releases and pick the newest `cli-v*` tag.
4. **Versioning.** ADR 0002 lets a shell release on its own (section 3). The
   CLI is at `0.7.0`, the same as core. Proposal: the first CLI release is
   `cli-v0.8.0`, since the interface changes completely.

### Plan

- [ ] `scripts/dev-install.ps1`: build from source and install locally,
      including the `cx.cmd` shim (the fastest dogfood loop, no release
      needed).
- [ ] `scripts/build.ps1` / `build.sh`.
- [ ] `.github/workflows/cli-release.yml`: on a push to `main` that changes
      `code/cli/pubspec.yaml`, if the tag `cli-vX.Y.Z` does not exist: run
      `dart test`, create the release, build Windows and Linux binaries, upload
      them.
- [ ] Guard the two app workflows with the tag filter.
- [ ] `scripts/install.ps1` / `install.sh`: download the newest `cli-v*`
      release, install it, create `cx`, add it to `PATH`.
- [ ] `cx upgrade` and `cx uninstall` from `InstallationPlugin` (D26, D33),
      as commands with `--plan` and `--apply`.
- [ ] `cx version` and `cx doctor` from `VersionPlugin` and `DoctorPlugin`,
      with the checks of `InstallationPlugin` (D31, D33).
- [ ] Check that `cx` does not collide with an existing command on the
      machine (`Get-Command cx`).

## Steps (one PR each)

| Step | Repository | Content | Depends on |
|---|---|---|---|
| S0 | calculatrix | Pending from before: the ENTER/delete fix and the Phase 0 docs. | Nothing |
| S1 | cli_router | Issue #4, PR #5: negative numbers and expressions are positionals. Release 0.1.1. | Nothing |
| S1b | cli_router, modular_cli_sdk | Releases 0.2.0 and 0.6.0 (D24), then migration of the consumers. | S1 released |
| S2 | calculatrix | CLI on `modular_cli_sdk` 0.6.0: banner, `eval rpn`, `eval infix`, the shortcut, the grammar of spec section 4, `dev-install.ps1`. Tests: every row of spec section 13 whose behavior S2 delivers. The rows of `version`, `doctor`, `upgrade` and `uninstall` are tests of S3; the rows of `commands`, of domain error ids (`unknown-word`, `stack-underflow`, `syntax-error`) and of the suggestion `cx version` are tests of S4. | S1b |
| S3a | modular_cli_sdk | Plugin system and standard plugins (D33): `VersionPlugin`, `DoctorPlugin` with `doctor.checks` and exit 78, `InstallationPlugin` with `upgrade` and `uninstall` as commands (D26) and the release lookup by tag prefix (D31). `macss` and `docmd` replace their own routes with them. Can ship inside 0.6.0 or as 0.6.x. | S1b |
| S3 | calculatrix | Publishing: release workflow, app workflow guards, installers, ADR 0002 amendment, the standard plugins from S3a. | S2, S3a |
| S4 | calculatrix | Core: command line parser and command registry with aliases and search terms (D29), `power` on matrices with a test per row of the D25 table, the domain error ids of spec section 6, `vector`, `append-rows`, `append-cols`, `rows`, space-separated matrix literals in RPN and infix, the core fixes of spec section 10. `eval rpn` and `commands` use it. | S2 |
| S5 | calculatrix | App: ENTER runs the command line, column 5 becomes delete, EVAL, ENTER, SPACE; `power` on the MATH page; `vector`, `append-rows` and `append-cols` keys on the MATRIX page. | S4 |

S3 and S4 can run in parallel after S2.

## Decisions log

| Date | Decision |
|---|---|
| 2026-09-23 | D1 to D9 above. |
| 2026-09-23 | D10 to D15, from the answers to Q1 to Q6. |
| 2026-09-23 | D16 to D18, from the answers to Q8 and Q9. |
| 2026-09-23 | D19 and D20, from the answers to Q7 and Q10. |
| 2026-09-24 | D21 to D24, the design of `docs/spec/calculatrix_cli.md`. |
| 2026-09-24 | D25 to D32, from the review of the spec, decision by decision (spec section 14, R1 to R17). D3 and D15 corrected, Q5 closed, Q3 and Q6 amended. No open question remains. |
| 2026-09-24 | D33, standard plugins in the SDK (spec R18). Replaces D20 and the package `modular_cli_installer`. Power table examples checked in Julia. |
| 2026-09-24 | D34, from the Codex review of PR #6 (spec R19 to R21). |

## Progress log

- 2026-09-23: Issue ccisnedev/cli_router#4 opened. Codex drafting the TDD fix
  (read-only sandbox; Claude applies, verifies, and opens the PR).
- 2026-09-23: PR ccisnedev/cli_router#5 open. 147 tests pass; seven consumer
  suites pass against the branch (modular_cli_sdk, macss, docmd, skillwire,
  datajack, inquiry, linkedin_cli). The first rule in the issue ("any token
  with whitespace is positional") would have broken `--title='two words'`; the
  issue and the tests were corrected.
- 2026-09-25: D38, from the Codex review of PR #7: declared precision range for
  matrix functions, `matrix-out-of-precision-range` added to the ids (spec R24).
- 2026-09-25: D37, from the Codex review of PR #7: matrix functions limited to
  five classes, `unsupported-matrix-function` added to the ids (spec R23).
- 2026-09-25: D36, one JSON error shape for every error (spec section 6).
- 2026-09-25: D35, from the Codex review of PR #7: `no-convergence` added to
  the ids (spec R22).
