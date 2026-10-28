# Research

Reports that informed decisions. They are evidence and reasoning at the date
they were written, not requirements. Decisions live in `../mission.md`,
`../roadmap.md`, `../spec/` and `../adr/`; when a report and one of those
disagree, the decision wins.

Status:

- **current**: still informs decisions.
- **superseded**: replaced by the document named.
- **historical**: written for an earlier stage of the project; kept as record.

## Language

| Report | Question | Conclusion | Status |
|---|---|---|---|
| [modern-stack-language-design/00-synthesis-and-recommendations.md](modern-stack-language-design/00-synthesis-and-recommendations.md) | Which language should cx's RPN grow into, and in what order? | A hybrid: quotations as values, control flow as words, definitions with declared stack effects, a step budget. | Partly superseded by [../spec/language-decisions.md](../spec/language-decisions.md). Quotations, definitions and control as words still apply; the `-> a b c { }` locals and the infix bridge do not. |
| [modern-stack-language-design/01-language-design-principles.md](modern-stack-language-design/01-language-design-principles.md) | Which design principles and evolution practices suit a small growing language? | Spec and grammar first, minimal orthogonal core, no implicit coercion, errors as a product, executable conformance suite. | Current (feeds language-decisions.md). |
| [modern-stack-language-design/02-concatenative-languages.md](modern-stack-language-design/02-concatenative-languages.md) | How do Forth, RPL, Factor, Joy, Uiua and others handle comments, definitions, locals, control flow and stack effects? | Trend toward quotations, checked stack effects, lexical locals and formatters. | Current as a survey; its locals recommendation is superseded by language-decisions.md. |
| [modern-stack-language-design/03-numeric-and-agent-languages.md](modern-stack-language-design/03-numeric-and-agent-languages.md) | What do numeric and bounded languages teach about exact vs approximate numbers and agent-safe design? | Silent exact-to-approximate promotion is the danger; add a deterministic step budget; structured errors serve agents best. | Current (supports mission principles 1, 2 and 5). |
| [modern-stack-language-design/04-specification-and-implementation.md](modern-stack-language-design/04-specification-and-implementation.md) | How to specify, implement and tool a small language, in backward-compatible phases? | Tree-walking interpreter over an AST, spec with executable examples, frozen regression corpus, tooling set. | Current for method; its version phases are superseded by [../roadmap.md](../roadmap.md). |
| [modern-stack-language-design/05-case-against-the-stack.md](modern-stack-language-design/05-case-against-the-stack.md) | Should the stack be the language's identity at all? | Devil's-advocate brief: for agent-written, human-reviewed code an expression surface is stronger. | Current. It led to the two-notation model in language-decisions.md. |
| [rpn.md](rpn.md) | What are RPN and HP-50g/RPL stack behaviour, and which stack model for the calculator app? | Dynamic internal stack with a 4-level visible window (option D). | Historical. HP 50g parity is no longer the 1.0 goal ([../mission.md](../mission.md)). |
| [rpn_state_of_art.md](rpn_state_of_art.md) | What is the academic and industry state of RPN and its alternatives? | RPN is best for physical calculators; software increasingly uses hybrid and graphical notations. | Historical; the two-notation decision is in language-decisions.md. |

## Engine

| Report | Question | Conclusion | Status |
|---|---|---|---|
| [sqlite-as-embeddable-engine-model/sqlite-embedding-model.md](sqlite-as-embeddable-engine-model/sqlite-embedding-model.md) | How does SQLite become an engine every host can embed, and what does that mean for calculatrix? | Dart cannot export a C ABI (Oct 2026), so the spec plus a language-neutral conformance suite is the primary asset; a native core (C API and WASM) is the second engine. | Current. It informs roadmap stage 7 and `../spec/engine-api-contract.md`. Any suggestion of embedding Giac as a kernel is superseded by [../adr/0004-pure-dart-engine-and-clean-room.md](../adr/0004-pure-dart-engine-and-clean-room.md). |

## Numerics and mathematics

| Report | Question | Conclusion | Status |
|---|---|---|---|
| [matrix_calculus_foundations.md](matrix_calculus_foundations.md) | Is treating scalars, vectors and matrices as one matrix domain sound? | Yes: 1×1, 1×N, N×1 and N×M belong to one algebraic structure; includes practical scope limits. | Current. It underpins "every value is a matrix" in the mission. |
| [scalar-promotion-matrix-algebra.md](scalar-promotion-matrix-algebra.md) | When is a scalar k legitimately the matrix kI? | Promotion k to kI is the ring embedding into the centre, valid only for square matrices of fixed order; not automatic with 2×2 complex blocks. | Current. |
| [matrix-representation-imaginary-unit.md](matrix-representation-imaginary-unit.md) | Why can the imaginary unit be the 2×2 matrix J? | {aI + bJ} is a field isomorphic to C; conjugation is transpose, modulus squared is the determinant. | Current. It underpins complex numbers as 2×2 blocks (roadmap stage 5). |

## App and UI

| Report | Question | Conclusion | Status |
|---|---|---|---|
| [casio-hl-820lv.md](casio-hl-820lv.md) | How does the Casio HL-820LV pocket calculator lay out keys and behave? | Reference of layout, specs and chain (left-to-right, no precedence) calculation. | Historical. |
| [google-calculator.md](google-calculator.md) | How does Google Calculator parse and evaluate input? | Infix with full precedence and live preview; a declarative model. | Historical. |
| [ui-ux-design-methodology.md](ui-ux-design-methodology.md) | How should an AI agent design a usable UI without a human designer? | Heuristic-Driven Component Design: Material 3 tokens, Nielsen heuristics, iterative validation. | Current for the app; method only. |

## Distribution

| Report | Question | Conclusion | Status |
|---|---|---|---|
| [winget-installer-format-2026.md](winget-installer-format-2026.md) | Is Inno Setup the right installer for a WinGet submission of the Flutter Windows app? | WinGet recommends no single format; Inno Setup is supported and a strong fit for self-hosted distribution. | Current. |

## Process

| Report | Question | Conclusion | Status |
|---|---|---|---|
| [council-synthesis-release-readiness.md](council-synthesis-release-readiness.md) | What analysis and validation is needed before the first release of the app and core package? | Tiered blockers: Android app id and signing, privacy policy, pub.dev dry run and example, ill-conditioned test matrices. | Historical. It targeted the first app and package release; the plan is now `../roadmap.md`. |
