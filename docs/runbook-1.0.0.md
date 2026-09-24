# Runbook: 1.0.0 = HP 50g Parity

Actionable plan from the current `v0.7.x` line to `1.0.0`. Update this file as
work lands: tick the box, add the PR or commit, and append a line to the
progress log.

Origin: issue #1 (Giac as the symbolic kernel) and its review against
`docs/roadmap.md`, `docs/architecture.md`, `docs/spec/calculatrix_core.md`, and
ADR 0003. The plan was reviewed by a second model on 2026-09-23; its findings
are folded into the phases below.

## Definition of 1.0.0

`1.0.0` ships when Calculatrix reaches **first parity with the HP 50g**:

1. A closed, versioned catalog of HP 50g commands exists
   (`docs/parity/hp50g.yaml`). Every command in it is classified as `v1`
   (required for 1.0.0), `later`, or `excluded` (with a reason).
2. Every `v1` command is implemented by at least one kernel (`DartKernel` in
   core or `GiacKernel` in `calculatrix_giac`), and is covered by **parity
   fixtures**: the manual's worked examples when the HP 50g Advanced User's
   Reference Manual gives one, and independently derived contract tests when
   it only gives a generic contract. Each fixture states the initial stack,
   the settings, the expected stack effect or error, and the comparison
   policy.
3. Parity means matching the HP contract (domain, normalization, output
   order, stack effect), not only the command name. Differences are either
   fixed, adapted, or documented as deliberate.
4. Every command lives in the core **command registry**, with its module and
   the kernels that support it. Each module is a button, each command is a
   button.
5. App and CLI read the registry. A test proves that every registered command
   is either reachable (app button, CLI alias) or explicitly marked as not
   exposed in that consumer. Parity is proven at package level; consumers may
   expose a subset.
6. The public API and error contract are reviewed and stable, with a
   migration guide from `0.x`.
7. License compliance, including corresponding-source delivery, is complete
   on every channel.

`DartKernel` coverage of the catalog is reported as a separate metric. It is
not a requirement for `1.0.0`.

## Package layout

| Package | Path | Content | License |
|---|---|---|---|
| `calculatrix` | `code/core` | Contract (`Value`, `CalculatrixKernel`, commands, registry, conformance suite), `DartKernel`, kernel selection | MIT |
| `calculatrix_giac` | `code/giac` | C shim over Giac, FFI and WASM bindings, `GiacKernel` | GPL-3.0-or-later |
| `calculatrix_cli` | `code/cli` | CLI consumer | GPL-3.0-or-later from the first Giac-linked release |
| `calculatrix_app` | `code/app` | Flutter consumer | GPL-3.0-or-later from the first Giac-linked release |

- `calculatrix` stays independent: it works on its own, in pure Dart, with
  `DartKernel` as the default. `DartKernel` code lives under
  `lib/src/kernel/dart/`, separate from the contract, so a consumer can choose
  which kernel to use.
- The adapter is named `calculatrix_giac`, not `giac`: it is Calculatrix's
  adapter to Giac, not Giac itself, and it follows the `calculatrix_*` naming
  of the other packages. Future kernels follow the same pattern, for example
  `calculatrix_julia` for a kernel served from a backend.
- SDK floors: core and CLI declare `sdk: ^3.8.1` today, the app `^3.11.5`.
  Build hooks need Dart 3.10 or later, so `calculatrix_giac` and the
  Giac-enabled CLI raise their floor; the core keeps its own floor unless its
  code needs more.
- `calculatrix_giac` declares a compatible `calculatrix` version range, and
  that range is tested in CI.

## Rules for working this runbook

- One phase at a time. Do not mix distribution work with engine work. The
  Dart kernel track is the exception: it runs in parallel once its start
  conditions hold (see Track D).
- Each phase ends with a stable `0.N.0` release (ADR 0002).
- TDD first, as in the roadmap testing policy.
- Architecture decisions go into an ADR before code depends on them.
- License compliance is checked per target actually distributed: a target
  does not ship until its own compliance tasks are done.
- When a box is ticked, write the PR or commit next to it.

---

## Phase 0: Planning documents

- [x] Correct issue #1 (edited 2026-09-23):
  - [x] vectors are `n×1` columns, not `1×n`
  - [x] core owns the contract (`Value`, `CalculatrixKernel`, commands,
        registry, conformance suite) and ships `DartKernel`; other kernels
        are implementations in their own packages; commands no kernel
        supports throw `UnsupportedCalculatrixOperationError`
  - [x] the conformance suite is exported by core
        (`package:calculatrix/conformance.dart`) and run by
        `calculatrix_giac`; core never depends on `calculatrix_giac`
  - [x] `SymbolicValue` vs core design principles 2 and 3: equality by
        canonical text, handle ownership, determinism per kernel
  - [x] root `LICENSE` becomes a per-component notice
  - [x] license decision for `code/api` (GPL does not cover network use)
  - [x] package `calculatrix_giac` at `code/giac/`, Giac as a submodule of
        the GeoGebra fork
  - [x] native library packaging through Dart build hooks (native assets)
  - [x] GPL notice and source link also on the web build
  - [x] ADRs 0004 (kernel seam), 0005 (value model, amends ADR 0003),
        0006 (licensing), 0007 (`CompositeKernel`)
  - [x] the Dart kernel track and its clean-room policy
  - [x] link this runbook
- [x] Second correction of issue #1, from the plan review (edited 2026-09-23):
  - [x] the API is not "synchronous by default": worker and isolate
        execution is asynchronous, and ADR 0004 decides the model
  - [x] a `sealed class Value` cannot be extended from `calculatrix_giac`;
        the value model needs an open subtype or a core-owned symbolic value
  - [x] remove "Calculatrix is already ahead" (the HP 50g has LU, QR, SVD,
        eigen commands); parity is judged by contract, not by name
  - [x] corresponding-source delivery in the compliance checklist
  - [x] build hooks raise the SDK floor of `calculatrix_giac` and the CLI
- [ ] Open issue #2 "1.0.0 = HP 50g parity" with the definition above
- [x] Add Stages 9 to 12 and the "1.0.0 gate" section to `docs/roadmap.md`
- [x] Add a "Kernel seam (planned)" section to `docs/architecture.md`
- [x] Fix the broken link to `docs/spec/stage_3_matrix_stack_machine.md` in
      `docs/architecture.md` (the file was removed in the pre-1.0 history
      cleanup; the link now points to `spec/calculatrix_core.md`)
- [x] Sync the Stage 8 checkboxes in the roadmap with the existing
      `android-release.yml`, `windows-release.yml`, and `pages-release.yml`
      (web live; Android identity and signing done; Play in closed testing;
      `winget` and Store not published; release workflows do not run tests)
- [x] Decide the pre-1.0 release path: ADR 0002 section 8 amended
      (2026-09-23). Every public release, `0.x` included, gets an immutable
      `vX.Y.Z` tag on the built revision; `v0.7.1` was already tagged.

Done when: both issues are published, the roadmap points to this runbook,
and the release-path decision is recorded.

## Phase 1: Parity specification

- [x] Obtain the HP 50g Advanced User's Reference Manual (HP part
      F2228-90010) and record the edition used (see Sources below)
- [ ] Define the catalog schema in `docs/spec/hp50g_parity.md`:
      `hp_name`, `hp_menu`, `object_types`, `arity`, `class`
      (`v1` / `later` / `excluded`), `reason`, `module`, `calculatrix_name`,
      `manual_page`, `contract_notes`, `status.dart`, `status.giac`,
      `status.cli`, `status.app`
- [ ] Define the fixture format: initial stack, settings (exact or
      approximate mode, angle mode, other relevant flags), command, expected
      stack or error, comparison policy (`exact`, `approximate` with
      tolerance, `algebraically_equivalent`, `presentation`), source
      (`manual` with page, or `derived` with justification)
- [ ] Extract every command from the manual into `docs/parity/hp50g.yaml`
- [ ] Classify each command (draft by subagent, final review by hand)
- [ ] Map HP menus to Calculatrix modules (current bar: `BASIC`, `STACK`,
      `MATH`, `MATRIX`, `VECTOR`, `FACT`, `PROP`, `EDIT`, `BUILD`, `MEM`)
- [ ] List commands `DartKernel` already implements (LU, QR, EIG, DET, SVD,
      ...) as **candidates only**, then compare each contract with the
      manual: domain, normalization, output order, stack effect. Known case:
      Calculatrix `LU` pushes `P, L, U` with unit-diagonal `L`; the manual
      must be checked for the HP order and normalization
- [ ] For each difference, decide: HP-compatible command, adapter, or
      documented deliberate difference
- [ ] Write fixtures for each `v1` command: manual examples where they exist,
      derived contract tests otherwise
- [ ] Script that prints coverage per class, per kernel, and per consumer

Done when: the catalog is reviewed, the `v1` count is frozen for 1.0.0, and
every `v1` command has at least one fixture.

### Sources

Official HP PDFs, verified on 2026-09-23 from the title pages. HP's notice
forbids reproduction without permission, so the repository stores only the
reference and the checksum, never the PDF. Each contributor downloads the
file and checks the SHA-256.

| Document | HP part | Edition | Pages | URL | SHA-256 |
|---|---|---|---|---|---|
| Advanced User's Reference Manual (HP 50g / 49g+ / 48gII) | F2228-90010 | 2, printed 2009-07-14 | 693 | <https://h10032.www1.hp.com/ctg/Manual/c02836298.pdf> | `5134a98cd7a7c7ea90f98c5ceec2b4c2670dcb20a2ef1f94cca3a0b910f8d46f` |
| HP 50g User's Guide | F2229AA-90006 | 1, April 2006 | 887 | <https://h10032.www1.hp.com/ctg/Manual/c00748644.pdf> | `890af4bcce8974bab3867c7783c77e9b63f08f3d2e53e13bc7adeddda8b04122` |
| HP 50g User's Manual | F2229AA-90001 | 1, April 2006 | 184 | <https://h10032.www1.hp.com/ctg/Manual/c00748646.pdf> | `fbab42f5c2235ecf159734dfc0a7c17c03b9142b5dc10c43852c9af96d35ff08` |

The Advanced User's Reference Manual is the authority for the catalog: it
lists every command with its stack diagram. The User's Guide supplies worked
examples for fixtures. `manual_page` in the catalog refers to the page
printed in the AUR, not the PDF page index.

## Phase 2: Stage 8, public distribution (`0.8.0`)

- [ ] Implement the release path decided in Phase 0 (tags `vX.Y.Z` per ADR
      0002 section 8) and update `docs/release-checklist.md`
- [ ] Google Play production access: follow
      `store/closed-testing-production-access-plan.md` (feedback log,
      traceability matrix, releases in the same closed track). Each Play
      upload needs a `versionCode` above the highest one already in Play
      Console
- [ ] Pin the Flutter and Dart toolchain versions used by release workflows
      instead of the moving `stable` channel
- [ ] Web on `calculatrix.ccisne.dev` through `pages-release.yml`
- [ ] Windows installer lineage and `winget`
- [ ] Google Play from the signed AAB
- [ ] Microsoft Store package identity
- [ ] Release pipeline gated by the core/app/cli validation matrix
- [ ] Cut `0.8.0`

Done when: the four channels serve the same validated revision.

## Phase 3: Stage 9, kernel seam and command registry (`0.9.0`)

No behavior change. All existing tests stay green.

- [ ] Resolve the tolerance conflict before exporting any conformance suite:
      `docs/spec/calculatrix_mathematics.md` says `1e-14` absolute /
      `1e-13` relative, `numeric_policy.dart` uses `1e-12` / `1e-10`. Pick
      the authoritative values and per-operation comparison rules, and make
      spec and code agree
- [ ] ADR 0004: kernel seam, kernel selection, and **execution model**. It
      must decide synchronous vs asynchronous execution for local workers
      (`Isolate.run` returns a `Future`, Web Workers talk by messages) and
      for remote kernels, and define command ordering, pending-state
      presentation, error delivery, and when results commit to the stack
- [ ] ADR 0005: value model and presentation (amends ADR 0003). It must
      decide:
  - [ ] how kernel packages add value types, given that a `sealed class`
        cannot be extended outside its library (open subtype such as
        `KernelValue`, or a core-owned symbolic value holding an abstract
        reference)
  - [ ] backend-neutral representation and kernel/context identity of a
        value
  - [ ] ownership for stack copies, memory registers, and kernel switching
  - [ ] how values cross isolates and workers (`NativeFinalizer` and
        `Finalizable` objects cannot be sent; the web has no `dart:ffi`):
        serialized values or release messages
  - [ ] equality (canonical text) and presentation of symbolic values
- [ ] `CalculatrixKernel` interface in core, following ADR 0004
- [ ] Move the current algorithms into `DartKernel` under
      `lib/src/kernel/dart/`
- [ ] Commands call the kernel instead of `Matrix` methods
- [ ] Kernel selection API: `DartKernel` by default, any
      `CalculatrixKernel` injectable by the consumer
- [ ] Export the conformance suite from core, parametrized by kernel, using
      the tolerances fixed above
- [ ] `Value` hierarchy per ADR 0005 with `NumericMatrix`; migrate
      `RpnEngine`, session, formatter, app, and CLI off `List<List<double>>`
- [ ] Command registry in core: name, HP name, module, arity, label,
      supported kernels
- [ ] App module bar and command pages generated from the registry
- [ ] CLI aliases generated from the registry
- [ ] Reachability tests for app and CLI
- [ ] Parity report wired into CI (reads the catalog and the registry)
- [ ] Migration notes for the public API changes of this stage
- [ ] Cut `0.9.0`

## Phase 4: Stage 10, Giac spike on CLI (`0.10.0`)

Targets distributed with Giac in this phase: CLI and Windows only.

- [ ] ADR 0006: licensing
- [ ] Build Giac on Windows (choose MSVC or MinGW, document it)
- [ ] C shim: request/response ABI, handle create/free, ownership rules
      following ADR 0005
- [ ] `code/giac/` package `calculatrix_giac`: FFI bindings, `GiacKernel`,
      build hooks
- [ ] Declare and test the SDK floor of `calculatrix_giac` and the CLI
      (Dart 3.10 or later for build hooks) and a pinned toolchain
- [ ] Declare and test the `calculatrix` version range supported by
      `calculatrix_giac`
- [ ] CLI flag `--kernel dart|giac`
- [ ] Conformance suite green on `GiacKernel`; divergences recorded in an ADR
- [ ] Differential test harness: same command on `DartKernel` and
      `GiacKernel`, report any disagreement (lives in `calculatrix_giac`
      tests, so core never depends on Giac)
- [ ] Measure binary size, cold start, per-call latency
- [ ] License change:
  - [ ] GPL-3.0 `LICENSE` in `code/app`, `code/cli`, `code/giac`
  - [ ] per-component notice in root `LICENSE` and `README.md`; keep the
        MIT notice for the core code inside the combined work
  - [ ] licenses page in the app (`showLicensePage`) with Giac notice and
        source link
  - [ ] CI check: `code/core` has no dependency on `calculatrix_giac`
- [ ] Audit Giac dependencies (GMP, MPFR, ...) for GPL compatibility
- [ ] Corresponding-source delivery for the CLI and Windows artifacts:
  - [ ] each release publishes an immutable source archive or revision of
        the combined work
  - [ ] pinned Giac revision, submodule revisions, and any local patches
  - [ ] build scripts and toolchain versions
  - [ ] mapping from each artifact (checksum) to its source
  - [ ] verified by rebuilding from the published source
- [ ] Store listings and legal pages mention the license and source URL for
      the targets shipped in this phase
- [ ] Cut `0.10.0`

## Phase 5: Stage 11, exact and symbolic values (`0.11.0`)

- [ ] ADR 0007: `CompositeKernel` (see the analysis below); decide go or
      no-go before implementing. Routing must depend on the command, the
      operand domain (numeric, exact, symbolic), and the evaluation mode,
      not on the command alone
- [ ] If go, and only after ADR 0007 defines lossless conversion rules:
      `CompositeKernel`, plus tests for mixed-kernel command chains
- [ ] Symbolic values per ADR 0005; `NativeFinalizer` only in the native
      adapter, release messages or serialized values for workers and web
- [ ] Parser: exponentiation `^` with precedence and right associativity
- [ ] Parser: exact numeric literals (large integers, rationals) kept exact
      instead of `double.tryParse` / `toDouble()`
- [ ] Parser: identifiers and named functions in the infix tokenizer
- [ ] Symbolic matrix literals (`[[3*y, 3*x], [2, x^2-3]]`)
- [ ] Round-trip tests through CLI and app for large integers, rationals,
      symbolic cells, and exact-to-approximate conversion
- [ ] Exact vs approximate mode (`→NUM`)
- [ ] CAS commands: `SIMPLIFY`, `EXPAND`, `FACTOR`, `SUBST`, `SOLVE`, `∂`,
      `∫`, `LIMIT`, `TAYLOR`, `CHARPOLY`, symbolic `DET` / `INV` / `TRACE`
- [ ] Text and LaTeX rendering in CLI and app
- [ ] Windows app reaches the same capabilities as the CLI
- [ ] Acceptance: `[[3*y, 3*x, y+3], [2, x^2-3, 5], [3, y, 1]] TRACE`
      returns `x^2 + 3*y - 2`
- [ ] Update `docs/spec/calculatrix_core.md` (CAS no longer out of scope)
- [ ] Migration notes for the public API changes of this stage
- [ ] Cut `0.11.0`

### `CompositeKernel` analysis (input for ADR 0007)

Advantages:

- Dart first: every command already in Dart runs without Giac, offline and
  on every platform.
- On the web, commands covered by Dart never wait for the Giac WASM module.
- Progressive: each command ported to Dart reduces the dependency on Giac
  without blocking the product.
- Differential testing comes almost for free, because both kernels answer
  the same registry.

Disadvantages and risks:

- Support is not per command: `DartKernel` supports numeric `DET` long
  before symbolic `DET`. Routing by command alone would send symbolic or
  exact operands to the wrong kernel or force lossy conversions.
- Mixed representations: a value created by Giac and consumed by a Dart
  command needs a conversion, and the reverse too. This needs a canonical
  interchange format both kernels read and write, without loss.
- Canonical forms differ (`2x` vs `2*x`, term order, sign conventions). A
  chain of commands could alternate styles unless the output is normalized.
- Results depend on the routing table, which changes as Dart grows. The same
  input could change form between versions; the table must be versioned and
  visible, and observable changes follow SemVer.
- Debugging: every result must say which kernel produced it.
- No size saving: Giac still ships, unless it is loaded lazily.

Questions the ADR must answer:

- Routing key: command, operand domain, and mode. Which combinations exist?
- Interchange format: a subset of Giac syntax, or a Calculatrix format?
- Does the user see or choose the routing (for example a `KERNEL` setting)?

## Phase 6: Stage 12, all platforms (`0.12.0`)

- [ ] Giac for Android through the NDK (GeoGebra build as reference)
- [ ] Giac WASM on the web through `dart:js_interop`, loaded lazily in a
      Web Worker; the numeric calculator never waits for it
- [ ] Heavy computations in `Isolate.run` on native, following ADR 0004
- [ ] Before shipping Android with Giac: corresponding-source delivery,
      build instructions, store listing, and licenses page for Android
- [ ] Before shipping the web with Giac: corresponding-source delivery,
      build instructions, and licenses page for the web build
- [ ] Cut `0.12.0`

## Phase 7: Parity completion (`0.13.0` and later)

One stage per HP menu group, in the order fixed by the catalog.

- [ ] Order the `v1` groups (for example ARITH, ALG, CALC, MATR, CMPLX,
      STAT, SOLVE, UNITS, PRG)
- [ ] Per group: fixtures, implementation, registry entries, catalog
      status, `0.N.0` release

## Phase 8: 1.0.0 gate

- [ ] Catalog: every `v1` command supported by at least one kernel
- [ ] Fixtures green on every kernel that claims a command
- [ ] Every contract difference with the HP 50g is fixed, adapted, or
      documented
- [ ] Reachability tests green; unexposed commands listed per consumer
- [ ] `DartKernel` coverage of `v1` published in the release notes
- [ ] Public API and error-contract review of `calculatrix` (including the
      exported conformance API) and of `calculatrix_giac`
- [ ] Migration guide from `0.x` to `1.0.0`
- [ ] Version compatibility between `calculatrix` and `calculatrix_giac`
      documented and tested
- [ ] License compliance, including corresponding-source delivery, checked
      on web, Windows, Android, CLI
- [ ] Docs: roadmap, architecture, specs, and ADRs match the shipped state
- [ ] Cut `1.0.0` on every channel

---

## Track D: Dart kernel (continuous)

A pure Dart CAS inside `DartKernel`, MIT, verified against Giac and against
the HP 50g manual. It runs in parallel with the phases.

### Start conditions and versioning

- Level 1 and 2 (exact numbers, exact linear algebra) may start after
  Phase 3, because they need the kernel seam and ADR 0005.
- Levels that need differential tests start after Phase 4.
- Before `1.0.0`, a ported command is a compatible core feature: it ships in
  the next `0.N.z` slice, as ADR 0002 allows for pre-1.0 work. After
  `1.0.0`, normal SemVer applies: new commands are minor bumps, and a
  routing change that alters observable results counts as a change of
  behavior.

### Clean-room policy

`DartKernel` is MIT and Giac is GPL, so `DartKernel` must never become a
derived work of Giac. This strict separation is the project's chosen policy.

- Giac is used only as a black box: send an input, compare the output.
- Reading Giac's **public API** (headers and documentation) is allowed for
  the C shim in `calculatrix_giac`. Reading Giac's **algorithm
  implementations** is not allowed for anyone working on `DartKernel`.
- No Giac code, comment, or table is copied, translated, or ported.
- Algorithms come from books and papers. Reference texts:
  Geddes, Czapor, Labahn, *Algorithms for Computer Algebra* (1992);
  von zur Gathen, Gerhard, *Modern Computer Algebra* (3rd ed., 2013).
- Test expectations come from the HP 50g manual or from mathematics, and
  Giac output is used only to detect disagreement.
- The policy applies equally to AI agents: an agent working on `DartKernel`
  must not be given Giac source files or be asked to read them.

Procedure:

- [ ] Provenance record: each `DartKernel` algorithm cites its source (book,
      chapter, page, or paper) in a doc comment, and each PR says where the
      algorithm came from
- [ ] Review rule: a `DartKernel` PR without a provenance citation is not
      merged
- [ ] Clean-room policy in the root `README.md`
- [ ] Clean-room policy in `code/core/README.md`
- [ ] Clean-room policy in `CONTRIBUTING.md` (create it), so external
      contributors accept it before sending code

### Order of difficulty

Work in this order. Each level depends on the previous one.

1. [ ] Exact rationals over `BigInt`, exact vs approximate mode
2. [ ] Exact linear algebra over rationals (DET, INV, RREF, rank without
       floating-point tolerance)
3. [ ] Expression trees, identifiers, substitution (`SUBST`)
4. [ ] Polynomials in one variable: arithmetic, division, GCD, `EXPAND`
5. [ ] Symbolic differentiation (`∂`)
6. [ ] Simplification with a canonical form
7. [ ] Multivariate polynomials, `CHARPOLY`, symbolic `DET` / `TRACE`
8. [ ] Factorization over the rationals (`FACTOR`)
9. [ ] Limits and series (`LIMIT`, `TAYLOR`)
10. [ ] Equation solving (`SOLVE`), polynomial first
11. [ ] Symbolic integration (`∫`): rational functions first; the general
        Risch algorithm is a multi-year project, so Giac covers it for a long
        time

Each level ends when its commands pass the parity fixtures and the
differential tests against Giac, and the catalog shows `status.dart = done`.

---

## Open questions

- Whether remote kernels (for example `calculatrix_julia` behind
  `code/api`) share the execution model of local workers, or stay outside
  the stack machine. Decided in ADR 0004 together with the local model.

## Decisions log

| Date | Decision | Where |
|---|---|---|
| 2026-09 | Giac is the symbolic kernel; Julia rejected as the embedded engine | issue #1 |
| 2026-09 | Core MIT; `calculatrix_giac`, app, CLI GPL-3.0-or-later | issue #1 |
| 2026-09 | `1.0.0` = first HP 50g parity, proven at package level by contract, not by name | this runbook |
| 2026-09 | One module = one button, one command = one button, via a core registry | this runbook |
| 2026-09 | `DartKernel` stays inside core; core works on its own and the consumer chooses the kernel | this runbook |
| 2026-09 | Adapter package named `calculatrix_giac`; future kernels follow `calculatrix_*` | this runbook |
| 2026-09 | Pure Dart CAS in `DartKernel` under a clean-room policy; Giac is a black box | this runbook |
| 2026-09 | `CompositeKernel` to be decided in ADR 0007, routing by command, domain, and mode | this runbook |
| 2026-09 | License compliance per distributed target, including corresponding source | this runbook |
| 2026-09-23 | Every public release, `0.x` included, gets an immutable `vX.Y.Z` tag | ADR 0002 section 8 |
| 2026-09-23 | AUR F2228-90010, edition 2, is the parity authority; the PDF is not stored in the repo | Phase 1 |

## Progress log

- 2026-09-23: runbook created (Phase 0 started).
- 2026-09-23: added package layout, Dart kernel track, clean-room policy,
  order of difficulty, and `CompositeKernel` analysis.
- 2026-09-23: issue #1 corrected (Phase 0).
- 2026-09-23: plan review by a second model (14 findings), all folded in:
  execution model and value ownership in ADRs 0004/0005, routing by
  domain, parity by contract with fixtures, corresponding-source delivery,
  release-path conflict with ADR 0002, tolerance conflict, SDK floors,
  per-target compliance, parser tasks, API stability gate, clean-room
  procedure, Track D start and versioning.
- 2026-09-23: issue #1 corrected a second time with the review findings.
- 2026-09-23: Phase 0 docs: roadmap Stages 9 to 12 and 1.0.0 gate, kernel
  seam section in architecture, stage_3 link fixed, Stage 8 synced, ADR 0002
  amended for `0.x` tags. Phase 1: official HP manuals located and verified.
- 2026-09-23: usability fixes outside the phases, on branch
  `fix/rpn-enter-dup-and-empty-delete`: `ENTER` with no draft duplicates
  the top (HP 50g), `⌫` on an empty stack no longer shows `Error`.
