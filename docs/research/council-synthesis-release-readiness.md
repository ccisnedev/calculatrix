# Council of Experts — Synthesis: Release Readiness

## Problem Analyzed

¿Qué tipos de análisis, pruebas y validaciones debemos ejecutar antes de publicar
el primer release de Calculatrix (app Flutter + paquete Dart core) para usuarios
reales (estudiantes e investigadores de álgebra lineal)?

## Experts Convened

| # | Persona | Perspectiva | Confidence |
|---|---------|-------------|------------|
| 1 | Numerical Computing Specialist | Precisión IEEE 754, estabilidad algorítmica | high |
| 2 | QA Engineering Lead | Cobertura sistémica, regresiones, riesgo de producción | high |
| 3 | Package Ecosystem Maintainer | pub.dev scoring, API surface, semver | high |
| 4 | UX Researcher (Education) | Cognitive load, discoverability, accesibilidad | high |
| 5 | Release Engineer | CI/CD, distribución, plataformas, monitoring | high |

## Individual Dictamens

### Expert: Numerical Computing Specialist
**Perspective:** IEEE 754 failure modes, algorithmic stability under perturbation, and real-world condition numbers that students will encounter.

#### Findings

1. Tolerance policy is a single absolute threshold — no scaling-aware pivot threshold.
2. No ill-conditioned test matrices from the literature (Hilbert, Vandermonde, Frank, Pascal).
3. No backward-error or residual-norm assertions — only forward error (`closeTo`).
4. Eigenvalue algorithm has hard 200-iteration limit with opaque error on non-convergence.
5. Denman-Beavers sqrt uses non-standard scaling heuristic.
6. QR for eigenvalues: no exceptional shift strategy for clustered eigenvalues.
7. No tests for matrices ≥ 5×5.

#### Risks

- Hilbert matrix inverse produces garbage (κ(H₅)≈4.8×10⁵) — textbook exercise
- Eigenvalues of 4×4+ non-symmetric matrices fail silently
- RREF of nearly-dependent rows gives wrong rank (threshold not scaled)
- Spectral norm fails on rectangular matrices (sqrt of negative due to round-off)
- Users have no way to assess result trustworthiness (no condition number)

#### Recommendation

1. Add standard test matrices: Hilbert(3-6), Pascal(4-5), Frank(5), Vandermonde
2. Add residual-based assertions: ‖A·A⁻¹−I‖, ‖Ax−b‖/(‖A‖·‖x‖), ‖QR−A‖/‖A‖
3. Dimension stress tests: 5×5, 6×6, 8×8, 10×10
4. Specific failure-mode tests: repeated eigenvalues, eigenvalue=0, clustered eigenvalues, negative eigenvalue for sqrt
5. Document numerical limitations for users
6. Expose condition number estimate

---

### Expert: QA Engineering Lead
**Perspective:** Cobertura sistémica, prevención de regresiones, riesgo de producción.

#### Findings

- Core test pyramid solid (282 tests). Widget tests verify semantics partially.
- Integration tests only on Windows — Web and Android have zero E2E coverage.
- No golden tests (visual regression). No formal coverage measurement.
- No performance benchmarks with regression gates.
- CLI tests (12) cover happy paths only.
- No persistence/state lifecycle tests.

#### Risks

- Visual regression undetected (layout broken on Web/mobile)
- Matrix editor drag-and-drop untested on touch
- Overflow/NaN/Infinity not handled consistently in UI
- Accessibility broken in RPN/Matrix modes
- Web-specific bugs (clipboard, keyboard, viewport) without coverage

#### Recommendation

1. Coverage gate in CI: ≥80% core, ≥70% app
2. Golden tests: 1 per mode × 2 sizes minimum
3. Integration tests in Web (Chrome)
4. Edge-case numeric tests for UI error display
5. Accessibility audit test (semanticsLabel + tap target + contrast guidelines)
6. Performance benchmark with regression gate
7. State persistence tests
8. Fuzz tests for infix parser

---

### Expert: Package Ecosystem Maintainer
**Perspective:** pub.dev readiness, API surface, developer first impression.

#### Findings

- `example/` absent — guaranteed scoring penalty
- README outdated (version mismatch, broken relative links)
- `topics` limited to 3, missing `linear-algebra` and `math`
- Dartdoc not verified — likely incomplete documentation on public members
- API surface large for 0.x — `RpnEngine` exposed may be premature
- SDK constraint (^3.8.1) very recent, restricts user base
- Decomposition types co-located in matrix.dart (not idiomatically discoverable)

#### Risks

- `dart pub publish --dry-run` will likely fail
- Estimated pub score: ~100-110/160
- Breaking changes in exposed internals will frustrate early adopters

#### Recommendation

- P0: Create `example/example.dart`, run `dart pub publish --dry-run`, run `dart doc`
- P0: Fix README (version, links)
- P1: Add topics, consider hiding `RpnEngine` from barrel, lower SDK constraint
- P2: Screenshots, CONTRIBUTING.md
- Don't rush to 1.0 — publish as 0.x developer preview

---

### Expert: UX Researcher (Education Focus)
**Perspective:** Cognitive load, discoverability, first-session retention.

#### Findings

- No progressive disclosure — 30+ operations presented flat to first-time user.
- Vector/rectangular matrix creation is a workaround, not a workflow.
- Truncated labels ("RR", "SN") destroy the discovery loop.
- No error recovery/undo — one wrong DROP loses the matrix.
- Stack is opaque — only top entry visible, violates working memory limits.

#### Risks

- **Critical:** No rectangular matrix creation = cannot solve #1 use case (Ax=b)
- **Critical:** Redundant accessibility labels fail WCAG 2.1
- **High:** No onboarding + no help = ~70% of target audience lost immediately
- **Medium:** No undo discourages exploration

#### Recommendation

1. Rectangular matrix creation (explicit row/column dimension selector)
2. Contextual microcopy (long-press/hover shows operation description)
3. Visible stack (top 2-3 entries simultaneously)
4. Usability tests: 5 undergrad students × 4 task scenarios
5. Minimum onboarding: 3-screen overlay on first launch

---

### Expert: Release Engineer
**Perspective:** Reproducible, auditable distribution pipelines.

#### Findings

- CI is minimal (only flutter test + build web on ubuntu)
- Application ID is `com.example.calculatrix_app` — **Play Store will reject**
- Signing uses debug keys — no release AAB possible
- CLI marked `publish_to: 'none'`
- No git tags, no GitHub releases
- No privacy policy (required by stores)
- Defender workaround not in CI

#### Risks

- **Blocker:** Application ID `com.example.*` rejected by Google Play
- **Blocker:** Debug-signed AAB rejected by Play Console
- **Blocker:** No privacy policy → listing rejected
- **High:** No release workflow → non-reproducible builds
- **High:** CI doesn't test core/CLI → invisible regressions

#### Recommendation

1. Change application ID to `dev.ccisne.calculatrix`
2. Generate upload keystore + configure Gradle signing
3. Create `release.yml` CI workflow (core-test, cli-test, app-test, build-android, build-web, build-windows)
4. Create privacy policy (GitHub Pages)
5. Adopt git tagging: `v{version}` → triggers release workflow
6. Integrate crash reporting (Crashlytics or Sentry)

---

## Consensuses

Los 5 expertos coinciden independientemente en:

1. **Tests de dimensión mayor (≥5×5) son mandatorios** — Both numerical and QA experts flag that no test exceeds 4×4, which is exactly where algorithms start showing real-world failure modes.

2. **La documentación pública es insuficiente** — Package maintainer says dartdoc/example missing; UX researcher says no help/tooltips; numerical expert says limitations undocumented.

3. **Hay blockers duros de plataforma** — Release engineer identifies 3 hard blockers (app ID, signing, privacy policy) that prevent any store publication regardless of code quality.

4. **No hay medición formal de cobertura** — QA and package experts both identify this as a gap that prevents systematic improvement.

5. **Accesibilidad no está validada** — QA, UX, and package experts all flag accessibility as unverified and potentially failing standards.

## Dissents

- **UX** vs **Package Maintainer**: UX says "don't release without rectangular matrix creation (it's the #1 use case)"; Package maintainer says "publish 0.x as developer preview and iterate." **Resolution:** These aren't contradictory — publish the *package* as preview (it works for square matrices), but hold the *app* store listing until vector input is solved.

- **Numerical** vs **QA**: Numerical expert wants condition-number API exposed; QA lead doesn't mention it. **Resolution:** Condition number is a package API question (nice for v1.0) but not a testing blocker — residual-norm tests serve the same validation purpose.

- **UX** (wants onboarding overlay) vs **pragmatism** (delays release): **Resolution:** A README/help page linked from the app satisfies minimum viability without implementing an onboarding flow.

## Blind Spots

1. **Internationalization (i18n):** No expert mentioned localization. Matrix notation differs by region (comma vs dot decimal separator). For a math tool targeting global students, this matters.

2. **Offline capability:** No discussion of whether the web version works offline (PWA/service worker). Students in lectures may not have connectivity.

3. **Data export/import:** No expert discussed how users get matrices in/out (copy-paste, file import, LaTeX export). This is a key workflow for researchers.

4. **Battery/performance on mobile:** Large matrix operations (10×10 eigenvalues) could drain battery or freeze the UI on low-end phones without proper isolate usage.

5. **Legal (open source license vs store presence):** MIT license is permissive but no CLA or contributor agreement exists if the project accepts PRs.

## Final Recommendation

### Tier 1 — Hard Blockers (must fix before ANY release)

| # | Action | Owner |
|---|--------|-------|
| 1 | Change Android application ID from `com.example.*` | Release |
| 2 | Generate release keystore + configure Gradle signing | Release |
| 3 | Create privacy policy page | Release |
| 4 | Run `dart pub publish --dry-run` and fix all issues | Package |
| 5 | Create `example/example.dart` | Package |

### Tier 2 — Release Quality (before users see it)

| # | Action | Owner |
|---|--------|-------|
| 6 | Add standard test matrices (Hilbert 3-6, Pascal 4-5, Frank 5) | Numerical |
| 7 | Add residual-norm assertions (‖A·A⁻¹−I‖, ‖QR−A‖/‖A‖) | Numerical |
| 8 | Add dimension stress tests (5×5, 8×8, 10×10) | Numerical |
| 9 | Create release CI workflow (multi-platform test + build) | Release |
| 10 | Add coverage measurement + gate (≥80% core) | QA |
| 11 | Fix accessibility labels (remove redundancy, add descriptions) | UX |
| 12 | Fix README (version, broken links, pub badge) | Package |
| 13 | Run `dart doc` and document all public API members | Package |

### Tier 3 — User Experience (before app store listing)

| # | Action | Owner |
|---|--------|-------|
| 14 | Add rectangular matrix creation (row/column dimension control) | UX |
| 15 | Add contextual microcopy (long-press descriptions) | UX |
| 16 | Show visible stack (top 2-3 entries) | UX |
| 17 | Integration tests on Chrome (Web) | QA |
| 18 | Golden tests (visual regression per mode) | QA |
| 19 | Crash reporting integration (Sentry/Crashlytics) | Release |

### Tier 4 — Nice-to-have (post-release iteration)

| # | Action | Owner |
|---|--------|-------|
| 20 | Condition number estimate API | Numerical |
| 21 | Onboarding overlay (3 screens) | UX |
| 22 | Undo/history feature | UX |
| 23 | Performance benchmarks with CI gate | QA |
| 24 | Fuzz testing for infix parser | QA |
| 25 | i18n (decimal separator awareness) | Blind spot |

### Recommended Release Strategy

1. **Immediate:** Publish `calculatrix` package on pub.dev as `0.5.0` (developer preview) after fixing Tier 1 items for the package only (items 4, 5, 12, 13).
2. **Next 2 sprints:** Complete Tier 2 items → bump to `0.9.0` (release candidate).
3. **App store launch:** Complete Tier 3 items → launch as `1.0.0` on Google Play + Web.
4. **Windows:** Evaluate sideload MSIX without code signing for v1.0 (SmartScreen warning acceptable).
