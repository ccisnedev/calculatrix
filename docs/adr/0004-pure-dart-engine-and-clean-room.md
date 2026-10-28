# ADR 0004: Pure Dart Engine and Clean-Room Policy

**Status:** Accepted

## Context

The engine (`code/core`, package `calculatrix`) is MIT and must stay
embeddable on the SQLite model: small, self-contained, usable from any host
under a permissive license. It computes exactly with numbers today and will
compute symbolically (a CAS) later.

Giac is a mature CAS, but it is GPL-3. Linking it would make the engine GPL,
and would need native builds of Giac, GMP and MPFR on every platform. Giac is
still valuable as an independent reference to test against.

## Decision

### 1. The engine is pure Dart

All computation, numeric and symbolic, is implemented in Dart in the engine,
with no native dependency. Giac is never linked, shipped or called at run
time, even if the CAS takes years to build.

### 2. Giac is only a test oracle

Giac checks the engine in differential tests: the same input goes to both,
and the outputs must agree. These tests run in CI (Linux, Giac installed from
the distribution's packages) and locally where Giac is installed; they skip
where it is missing.

### 3. Clean room

The engine must never become a derived work of Giac.

- Giac is used only as a black box: send an input, compare the output.
- Nobody working on the engine reads Giac's source code. Its public
  documentation may be read.
- No Giac code, comment or table is copied, translated or ported.
- Algorithms come from books and papers, for example Geddes, Czapor and
  Labahn, *Algorithms for Computer Algebra* (1992), or von zur Gathen and
  Gerhard, *Modern Computer Algebra* (3rd ed., 2013).
- Each algorithm of the engine cites its source (book and chapter, or paper)
  in a doc comment, and the PR that adds it says where it came from. A PR
  without that citation is not merged.
- Test expectations come from mathematics. Giac output only detects
  disagreement.
- The policy applies equally to AI agents: an agent working on the engine is
  never given Giac source files or asked to read them.

## Consequences

- The engine stays MIT and runs wherever Dart runs, including the web.
- The CAS is slower to build than embedding Giac would be.
- Every algorithm has a traceable, clean origin.
