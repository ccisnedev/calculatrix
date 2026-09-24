# Runbook: CLI Stage 0

Stage 0 turns `code/cli` into a real, installable CLI named `calculatrix` (alias
`cx`), built on `modular_cli_sdk`, so it can be used every day (dogfood) before
the shared command line lands in core and in the app.

This file is for discussion first. Nothing in `code/cli` changes until the
"Open questions" section is settled. Update it as work lands: tick the box, add
the PR, and append a line to the progress log.

Parent plan: `docs/runbook-1.0.0.md`. This stage is the first slice of Stage 9
("Kernel Seam and Command Registry") in `docs/roadmap.md`.

## Goal

```text
cx                                   banner (later: a REPL with a live stack)
cx rpn eval '-1 2 +'                 prints the stack after running the line
cx infix eval '-1+2'                 prints the result
cx version
cx upgrade
```

The CLI, the app, and the future REPL run the same thing: an RPN command line
that is parsed into objects and then executed one object at a time against the
stack. The app is that with a keypad; the REPL is that without one.

## Decisions already made

| # | Decision | Source |
|---|---|---|
| D1 | The program is `calculatrix`, with `cx` as its alias. | User, 2026-09-23 |
| D2 | The CLI uses `modular_cli_sdk` and `cli_router`, structured like `macss/code/cli`. | User, 2026-09-23 |
| D3 | Every route is a query: no `--plan` or `--apply`. | User, 2026-09-23 |
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
| D15 | `upgrade` and `uninstall` are queries, as in `macss` and `docmd`. They belong in a package of the `modular_cli_sdk` ecosystem, because every CLI needs them. | User, Q6 |
| D16 | Command names that are not a single word use the cmdlet pattern `<verb>-<subject>`. | User, Q8 |
| D17 | There is no `matrix` command: everything is a matrix. Two join commands build matrices: `join-rows` stacks along the rows axis (vertically) and `join-cols` joins along the columns axis (side by side), when the sizes fit. | User, Q8 |
| D18 | `exp` is e^x, as on the HP. x^y is `power`, with aliases `pwr` and `^`. | User, Q9 |
| D19 | Each product in the repository has its own tag prefix. The CLI uses immutable `cli-vX.Y.Z` tags; the app keeps `vX.Y.Z`. `cx upgrade` filters releases by prefix and never uses `releases/latest`. | User, Q7 |
| D20 | `upgrade` and `uninstall` come from a new ecosystem package, `modular_cli_installer`, shared by every CLI (`macss`, `docmd`, `cx`). | User, Q10 |

## Command catalog (proposal)

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
| `join-cols` | none (closest: `COL+`) | `A B` gives `[A B]`; A and B need the same number of rows |
| `join-rows` | none (closest: `ROW+`) | `A B` gives A over B; A and B need the same number of columns |
| `rows` | `ROW→` | `[[...]]` gives `[row1] ... [rown] n` |
| `power`, aliases `pwr`, `^` | `^` | `x y` gives `x^y` |
| `exp` | `EXP` | `x` gives e^x |

Matching is case-insensitive. ASCII spellings of the HP names (`->ARRY`,
`ROW->`) are accepted as aliases for users coming from the HP. A row vector is
`1 2 2 vector transpose`, or the literal `[[1 2]]`.

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

  `--json` (global option from the SDK) prints the stack as a JSON array.
- [x] **Q4. Display format everywhere.** D6 makes spaces the input separator.
  Should `MatrixDisplayFormatter.compact` also print `[[0 -1] [1 0]]` instead of
  `[[0, -1], [1, 0]]`? That changes the app and the CLI tests.
- [ ] **Q5. Scope of the power command.** Proposal: real to real power, and a square matrix
  to an integer power. To verify in the AUR: negative base with a non-integer
  exponent (complex result on the HP), and what the HP does with a matrix
  power.
- [x] **Q6. Are `upgrade` and `uninstall` queries too?** D3 says every route is
  a query. In `macss` these two are commands, because they change the system.
  Proposal: follow D3, and have `uninstall` ask for confirmation.
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
- [ ] `cx upgrade` and `cx uninstall`, from `modular_cli_installer` (D20).
- [ ] Check that `cx` does not collide with an existing command on the
      machine (`Get-Command cx`).

## Steps (one PR each)

| Step | Repository | Content | Depends on |
|---|---|---|---|
| S0 | calculatrix | Pending from before: the ENTER/delete fix and the Phase 0 docs. | Nothing |
| S1 | cli_router | Issue #4, PR #5: negative numbers and expressions are positionals. Release 0.1.1. | Nothing |
| S2 | calculatrix | CLI on `modular_cli_sdk`: banner, `version`, `rpn eval`, `infix eval`, `dev-install.ps1`. | S1 released |
| S3a | modular_cli_installer | New ecosystem package with `upgrade` and `uninstall` (D20). | Nothing |
| S3 | calculatrix | Publishing: release workflow, app workflow guards, installers, ADR 0002 amendment, `upgrade` and `uninstall` from S3a. | S2, S3a |
| S4 | calculatrix | Core: command line parser and command registry with aliases, `power`, `vector`, `join-rows`, `join-cols`, `rows`, space-separated matrix literals in RPN and infix. `rpn eval` and `rpn commands` use it. | S2 |
| S5 | calculatrix | App: ENTER runs the command line, column 5 becomes delete, EVAL, ENTER, SPACE; `power` on the MATH page; `vector`, `join-rows` and `join-cols` keys on the MATRIX page. | S4 |

S3 and S4 can run in parallel after S2.

## Decisions log

| Date | Decision |
|---|---|
| 2026-09-23 | D1 to D9 above. |
| 2026-09-23 | D10 to D15, from the answers to Q1 to Q6. |
| 2026-09-23 | D16 to D18, from the answers to Q8 and Q9. |
| 2026-09-23 | D19 and D20, from the answers to Q7 and Q10. |

## Progress log

- 2026-09-23: Issue ccisnedev/cli_router#4 opened. Codex drafting the TDD fix
  (read-only sandbox; Claude applies, verifies, and opens the PR).
- 2026-09-23: PR ccisnedev/cli_router#5 open. 147 tests pass; seven consumer
  suites pass against the branch (modular_cli_sdk, macss, docmd, skillwire,
  datajack, inquiry, linkedin_cli). The first rule in the issue ("any token
  with whitespace is positional") would have broken `--title='two words'`; the
  issue and the tests were corrected.
