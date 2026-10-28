# Runbook

The single runbook of the repository: the work in progress, in order.
When a step is done, it is ticked here and its outcome lives where it
belongs (a spec, an ADR, the roadmap). Earlier runbooks are in the git
history.

Current goal: **put the repository in order.** One mission, one
roadmap, one runbook, specs that describe what exists, and issues that
match the roadmap. Then the language design continues.

## Phase 1. Order

- [x] **1.1 Mission.** `docs/mission.md` describes the ecosystem:
  language, engines, tools, numeric and symbolic computation.
- [x] **1.2 Roadmap.** Rewrite `docs/roadmap.md` as stages toward the
  mission. HP 50g parity and Giac stop defining 1.0.0; whatever is kept
  of them becomes a stage or is dropped explicitly.
  Done when: every stage says what it delivers and when it is done.
- [x] **1.3 Versioning.** ADR 0002 is corrected in place (its rule was
  a drafting error, not a decision that changed): each publishable
  package has its own version; one shared version applies only to the
  same package implemented in several languages.
  `docs/release-checklist.md` follows it.
- [x] **1.4 Specs describe what exists; the old runbooks go.**
  - `calculatrix_core.md`, `calculatrix_cli.md` and
    `calculatrix_mathematics.md` describe the current behavior and hold
    every rule of the old runbooks that still applies (the `power` table
    with its rows corrected, the literals, the command registry...).
  - The Giac and clean-room rules go to ADR 0004; the `BASIC` module
    map of `stage_7_honest_rpn_shell.md` goes to ADR 0003.
  - Code, tests, scripts and workflows cite no document: each comment
    states its rule directly, clear and brief.
  - The four runbooks and `stage_7_honest_rpn_shell.md` are deleted.
  - `language-decisions.md` and `engine-api-contract.md` stay as the
    working drafts of the language and the engine contract.
  Done when: `git grep -n runbook` outside `docs/` finds only the
  CHANGELOGs' past entries and the two tests that keep the word out of
  user-facing text.
- [x] **1.5 The rest of the docs.**
  - `docs/architecture.md` (written at v0.7.1) describes the current
    packages and the planned engine and tools.
  - The READMEs show current versions (`code/core/README.md` says
    0.5.0).
  - `docs/research/README.md` indexes the research reports: what each
    one asked and what it concluded.
  - `docs/pub.md` and `docs/android-release-signing.md` are checked
    against the current release process.
- [x] **1.6 Issues.** Each open issue is mapped to a roadmap stage,
  rewritten, or closed with a reason; the stages list their issues.
  Closed: #1 and #2 (Giac and HP 50g parity are no longer goals), #79,
  #92 and #74 (answered by `language-decisions.md` or replaced by
  phase 2), #75 (duplicate of #64), #90 (fixed in core 0.8.0), #11, #18
  and #50 (no case or need). A global option before a route
  (`cx --json version`) fails with `misplaced-option`; the fix belongs
  upstream, open as macss-dev/cli_router#10.
- [ ] **1.7 CI runs the CLI.** `ci.yml` analyzes and tests `code/cli`
  on every pull request (#95).
- [ ] **1.8 Merge.** One PR with phase 1 into main.

## Phase 2. Language specification

- [ ] **2.1 Settle the open questions** of `language-decisions.md`, in
  the order it states (O10, then O4, ...).
- [ ] **2.2 Write the versioned specification** of the language from
  the decisions: one document with a language version and its own
  change history, so the language evolves in this repository.
- [ ] **2.3 Update the engine contract** (`engine-api-contract.md`) as
  listed in "Impact on the engine contract".

## Working rules

- **Simplicity first.** Clear code and processes come from simple ones.
  The same holds for the products: the app and `cx` converge toward
  clarity and order, with no complexity they do not need.
- **Design decisions come from the user.** An automated review answers
  one bounded question (is the issue met, does main regress); a finding
  outside it becomes a new issue, not a change to the PR. If two or
  three rounds keep raising new findings, stop and revisit the premise.
- **Code cites no documents.** A comment or a test states its rule
  directly, clear and brief.
