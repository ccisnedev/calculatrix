# SQLite as the Model for an Embeddable Calculation Engine: Implications for calculatrix_core

## Abstract

SQLite is the reference case of a language (SQL) delivered as an embeddable engine that any host language can call. Its success rests on one C implementation (a single-file amalgamation), a very small and permanently stable C API (open, prepare, bind, step, column, finalize), a stable on-disk format, an extreme test regime and a public-domain licence [@sqlite2026lts; @sqlite2026testing; @sqlite2026amalg; @sqlite2026copyright]. Every mainstream language consumes that same C core through a thin binding (Python, Node, Rust, Dart) or through an official WASM build; native reimplementations (Turso in Rust, modernc.org/sqlite in Go) exist but remain either unfinished or a mechanical transpilation [@tursorepo; @tursocompat; @modernc]. Comparable precedents split into "one core plus bindings" (SQLite, Lua, RE2) and "spec plus conformance suite plus many implementations" (CEL, JSON Schema) [@lua54manual; @re2repo; @celspec; @jsonschematestsuite]. For calculatrix, the decisive Dart fact is that, as of the sources retrieved (October 2026), Dart cannot ship a C-ABI shared library: build hooks only let Dart consume native code, `dart compile` has no library target, and dart2wasm output targets JavaScript hosts [@darthooks; @dartcompile; @dartwasm; @dartsdk63412]. The recommended path is a language specification plus a language-neutral conformance suite as the primary asset, with the second engine written in Rust (or another single native core exposing a SQLite-shaped C API), while the Dart engine stays a first-class native implementation and `cx --json` serves as a bridge. Confidence: medium.

## Research Question

How does SQLite work as an embeddable engine callable from any language, and what does that imply for turning `calculatrix_core` (a Dart package implementing an exact-arithmetic stack-language engine) into an engine usable from Dart, TypeScript, Python, Rust and others?

## Scope and Constraints

- In scope: SQLite architecture and embedding surface; how Python, Node, Rust, Dart and browsers consume it; native reimplementations; Lua, CEL, JSON Schema, Jsonnet and RE2 as precedents; Dart's ability to export a C ABI; four architecture options for calculatrix.
- Out of scope: implementing any option, benchmarking, SQL language design itself, licensing advice.
- Constraints: evidence is gathered by web retrieval through a summarising fetch tool, so quotations are paraphrases of tool output, not verbatim page text, except where short quoted fragments were returned. The current repository API was skimmed only (`code/core/lib/calculatrix.dart` and class names). Date of research: 2026-10-03.
- The user's stated design intent: the calculation language is to computation what SQL is to data; hosts pass program text, bind parameters, execute; "compile" means validate, package and deploy (dacpac-like); the system should stay deterministic and hermetic.

## Method (Staged Protocol)

1. Problem framing: decompose the question into SQLite facts, consumer patterns, precedents, Dart constraints and option evaluation.
2. Source discovery: primary documentation first (sqlite.org, language manuals, project repositories, dart.dev, dart-lang/sdk issues), then web search for gaps.
3. Source triage: prefer the project's own documentation; treat GitHub issues as evidence of status, not of decisions; mark pages that returned nothing useful.
4. Evidence extraction: record per-claim facts with the source key.
5. Synthesis: map evidence onto the four options, state confidence, list limits.

## Findings by Stage

### Stage 1 - Problem Framing

Sub-questions: (a) which properties of SQLite make it embeddable everywhere; (b) which of those can be reproduced by calculatrix; (c) what Dart permits; (d) what it costs to keep exact arithmetic identical across languages.

Current calculatrix surface (skimmed): `lib/calculatrix.dart` exports `Calculatrix` (static `compileInfix`, `evaluateInfix`, `evaluateRpn`, `evaluateRpnStack`), `CalculatrixMachine` (`execute`, `executeAll`, `executeProgram`, `executeMacro`), `CalculatrixProgram`, `CalculatrixSession` (infix/RPN modes), `Matrix`, `Rational`, exact arithmetic/linear algebra/roots modules, a name table, a command registry and a typed error hierarchy (`CalculatrixError` and subclasses such as `ExpressionSyntaxError`, `RpnStackUnderflowError`, `LimitExceededError`, with a `CalculatrixErrorId` enum). The CLI `cx` already has JSON-related output modules. This maps naturally onto a prepare/bind/step/finalize shape: `compile` is prepare, the name table is bindings, the machine is the statement VM, the matrix is the result value.

### Stage 2 - Source Discovery

Sources consulted: SQLite pages (amalgamation, testing, long-term support, threading, C interface intro and object list, opcodes, copyright, WASM, SQL Logic Test) [@sqlite2026amalg; @sqlite2026testing; @sqlite2026lts; @sqlite2026threads; @sqlite2026cintro; @sqlite2026c3ref; @sqlite2026opcode; @sqlite2026copyright; @sqlite2026wasm; @sqlite2026slt]; binding docs (Python, Node, pub.dev, rusqlite) [@python3sqlite; @nodesqlite; @pubsqlite3; @rusqlite]; reimplementations (Turso, modernc) [@tursorepo; @tursocompat; @modernc]; precedents (Lua manual, CEL spec and language definition, JSON Schema suite, RE2, Jsonnet) [@lua54manual; @celspec; @cellangdef; @jsonschematestsuite; @re2repo; @jsonnet]; Dart (hooks, compile, wasm, SDK issues, wasm.dart) [@darthooks; @dartcompile; @dartwasm; @dartsdk63412; @dartsdk56366; @dartnativeext; @wasmdart; @dartsdk49035; @dartpragmas]; numeric libraries (Python fractions, num-rational, MDN BigInt) [@pyfractions; @numrational; @mdnbigint].

### Stage 3 - Source Triage

High weight: sqlite.org pages, Dart docs, Lua manual, project READMEs. Medium weight: GitHub issues (status only), search-result snippets about Dart issue contents. Low or unusable: the CEL home page and `tests/simple` directory listing yielded no implementation list or test format; jsonnet.org gave no implementation detail; the JSON Schema implementations page does not mention the test suite. These gaps are listed in Limitations.

### Stage 4 - Evidence Extraction

**4.1 SQLite architecture**

- Amalgamation: a single file `sqlite3.c`, concatenating over 100 source files, about 238K lines (145K excluding blanks and comments), over 8.4 MB; documented 5-10% speed gain from single-translation-unit optimisation, at the cost of larger binaries; "single file to manage and distribute" [@sqlite2026amalg].
- Lifecycle: two core objects, `sqlite3` (connection, `sqlite3_open`/`sqlite3_close`) and `sqlite3_stmt` (prepared statement, `sqlite3_prepare`/`sqlite3_finalize`); sequence prepare, bind, step, column, finalize; "think of prepare as compiling a small program into object code and step as running it"; `sqlite3_exec` is a convenience wrapper implemented over the core routines [@sqlite2026cintro; @sqlite2026c3ref].
- Errors: numeric result codes defined as macros in `sqlite3.h`, `SQLITE_OK` being success [@sqlite2026c3ref].
- Threading: three modes (single-thread, multi-thread, serialized), chosen at compile time (`SQLITE_THREADSAFE`), start time (`sqlite3_config`) or per connection (`SQLITE_OPEN_NOMUTEX`/`FULLMUTEX`); serialized is the default [@sqlite2026threads].
- VDBE: SQL is compiled by prepare into bytecode run by `sqlite3_step`; `EXPLAIN` shows the program; crucially "the bytecode engine is not an API of SQLite" and opcodes change between releases (192 opcodes in 3.53.4) [@sqlite2026opcode]. The stable contract is therefore the language plus the C API, not the intermediate representation.
- Stability: intent to support SQLite through 2050; the developers promise to keep the C API and on-disk format fully backward compatible; files are bit-identical across 32/64-bit and endiannesses; the US Library of Congress recommends the format for preservation [@sqlite2026lts].
- Testing: TH3 proprietary harness (about 1,055 KSLOC, 50,362 cases, 2.4 million parameterised instances) with 100% branch and 100% MC/DC coverage of the core; test code to source ratio about 590:1 (3.42.0); TCL tests, 7.2 million SQL Logic Test queries, dbsqlfuzz about 500 million cases per day, OSS-Fuzz [@sqlite2026testing]. SQL Logic Test deliberately compares results across independent engines instead of hand-written expectations [@sqlite2026slt].
- Licence: public domain, with an optional paid warranty of title; the project is "open-source, not open-contribution" [@sqlite2026copyright].

**4.2 Consumers**

- Python: the stdlib `sqlite3` module is a DB-API 2.0 (PEP 249) wrapper over the C library, with qmark and named placeholders and a reported linked library version [@python3sqlite].
- Node: `node:sqlite` (added v22.5.0; release candidate from v25.7.0) exposes synchronous `DatabaseSync`, `prepare`, `run/get/all/iterate`, positional and named binding, and maps INTEGER to number or BigInt [@nodesqlite]. (better-sqlite3 is the prior community equivalent; not separately retrieved.)
- Rust: rusqlite is an ergonomic wrapper over `libsqlite3-sys` (bindgen declarations); the `bundled` feature compiles the amalgamation into the build [@rusqlite].
- Dart: `package:sqlite3` uses `dart:ffi` natively and WASM on web, bundles SQLite via Dart hooks, and supports Android, iOS, macOS, Linux and Windows (version 3.7.0 at fetch time) [@pubsqlite3].
- Browser: the official build compiles the same unchanged C source with Emscripten and offers four JS API layers (C-style, OO, Worker, promise Worker) plus OPFS persistence [@sqlite2026wasm].
- Native reimplementations: Turso (Rust) tracks SQLite 3.50.4 at SQL, file-format and C-API levels, is beta, pursues deterministic simulation testing, but lacks several opcodes, UDFs via the C API, and some window functions [@tursorepo; @tursocompat]. modernc.org/sqlite is a CGo-free Go port produced by transpiling the C amalgamation with ccgo, motivated by avoiding CGo friction; it is roughly 1.3x to 2x slower and depends on a fragile libc package [@modernc]. Pattern: reimplementation by hand is slow and incomplete; reimplementation by transpilation preserves the single C source of truth.

**4.3 Other precedents**

- Lua: a C core whose API is itself a virtual stack ("whenever Lua calls C, the called function gets a new stack"), with no global variables (fully reentrant state object), protected calls for errors [@lua54manual]. Relevant to an RPN engine: the embedding API of a stack language is conventionally stack-shaped.
- CEL: a specification (language definition, AST as protobuf) with a dedicated conformance directory; hermetic and deterministic by design ("deterministically evaluate to either a value or an error"); non-Turing-complete, linear time [@celspec; @cellangdef]. The multi-language implementation list was not retrievable from the sources fetched (see Limitations); it is commonly known to include Go, Java and C++ (background knowledge, not sourced here).
- JSON Schema: language-agnostic JSON test suite, implementer converts cases into a native harness; used by many implementations across JavaScript, Python, Java, .NET, Go, Rust, PHP, Ruby [@jsonschematestsuite].
- Jsonnet: more than one implementation exists (C++ and Go repositories referenced) but retrieved details were thin [@jsonnet].
- RE2: one C++ core with official Python binding and many community ports (Java, JS, Go, Rust, Ruby, WASM and others); safety through linear-time matching [@re2repo].
- Trade-off synthesis: one core plus bindings gives bit-identical behaviour at low per-language cost but requires native build and distribution in each ecosystem; spec plus suite gives idiomatic, dependency-free implementations but behaviour drifts wherever the spec is silent (CEL had to state numeric equality semantics explicitly [@cellangdef]), and the suite becomes the real specification.

**4.4 Dart in 2025-2026**

- Shipped: build hooks (stable in Dart 3.10, link hooks in 3.13) let packages compile or download native code for Dart to call; the documentation states the mechanism is one-directional, Dart consuming native code, not exporting Dart [@darthooks].
- Shipped: `dart compile` offers exe, aot-snapshot, jit-snapshot, kernel, js and wasm; no shared-library target [@dartcompile].
- Shipped but constrained: Wasm compilation is on the stable channel but "in preview"; output targets JavaScript environments and "doesn't support execution in standard Wasm run-times like wasmtime and wasmer" [@dartwasm].
- Experimental: a `--standalone` dart2wasm mode and the `wasm.dart` project aim at wasmtime-runnable components; the project itself says it "can't handle much more than a hello world program"; the WASI support request (#56366) is open without assignment [@wasmdart; @dartsdk56366].
- Not available: a feature request for `dart compile dynamic-lib` (#63412) and earlier ones (#37480, #49035, #61824) exist; no official mechanism for a stable C-ABI library from Dart was found, and #63412 was closed on 2026-05-20 as a duplicate of #54846, with a Dart team member (mraleph) stating the team is "interested in doing this" but has "not been able to allocate resources", citing challenges in Dart's concurrency model [@dartsdk63412; @dartsdk49035]. Native extensions were removed in Dart 2.15; the Dart VM Embedding API remains supported for hosting the VM, with community examples, and it requires embedding the whole VM and `vm:entry-point` pragmas [@dartnativeext; @dartpragmas].
- Consequence: today a Dart core can reach other languages only as (i) a Dart process (CLI, subprocess), (ii) JavaScript via `dart compile js` or Wasm in a JS host, (iii) an embedded Dart VM (heavy, ergonomically poor).

**4.5 Numeric substrate per language**

- Python: `fractions.Fraction` over unlimited ints, normalised [@pyfractions].
- Rust: `num-rational` `BigRational` = `Ratio<BigInt>` [@numrational].
- JavaScript/TypeScript: native `BigInt` (baseline since 2020), no rational type, division truncates, not JSON-serialisable by default [@mdnbigint]. A Rational class must be written (small).
- Go (`math/big.Rat`), Java (`BigInteger`), C (GMP) are well known to offer equivalents but were not retrieved in this study.
- Implication: exact rationals are a solved problem in each ecosystem; the risk is not the bigint library but divergence in the semantics layered on top (roots, display formatting, rounding, limits, error identity).

### Stage 5 - Synthesis and Limits

Mapping SQLite properties to calculatrix:

| SQLite property | Calculatrix analogue | Status |
|---|---|---|
| Single implementation, amalgamation | One engine artefact | Only true in options B/C |
| prepare/bind/step/column/finalize | compile / bind names / run / read Matrix / release | API design, independent of option |
| Result codes in a header | `CalculatrixErrorId` enum as stable numeric codes | Exists as enum; needs freezing |
| Bytecode not public | Keep program text and results as the contract | Design choice |
| File format promise | Program text (language) and compiled package format | Needs versioning |
| TH3 and SLT conformance | Language-neutral test corpus | Biggest transferable asset |
| Public domain | Permissive licence | Author's choice |

#### Option evaluation

**(A) Per-language native engines plus shared conformance suite.**
- Determinism: achievable for exact integers and rationals (results are mathematically unique) if the suite pins every non-unique behaviour (output formatting, root representation, limit and error identity). Weakest point is anything involving floats or formatting. CEL's explicit numeric-equality text shows how much prose is needed [@cellangdef]; SQLite itself uses cross-engine comparison to avoid hand-written expectations [@sqlite2026slt].
- Libraries: all five target languages have bigints; rationals are available in Python and Rust, and trivial in TypeScript over BigInt [@pyfractions; @numrational; @mdnbigint].
- Effort: highest in total (N engines, N maintenance streams), but the author reports AI-agent-assisted three-language porting experience, which lowers marginal cost; the suite lowers the risk of drift. Cost does not shrink for evolution: each language-level change touches N codebases.
- Distribution: best (pure packages, no native build, runs in browsers, Flutter, serverless). Matches JSON Schema's ecosystem outcome [@jsonschematestsuite].
- Hermetic fit: strong (no FFI, no native supply chain).

**(B) One native core (Rust, C or Zig) exposing a SQLite-shaped C ABI, with bindings including Dart via FFI.**
- Determinism: strongest; one code path, results bit-identical. Same model as SQLite via Python, Node, Rust, Dart [@python3sqlite; @nodesqlite; @rusqlite; @pubsqlite3].
- Libraries: only one bigint/rational stack needed (num-bigint in Rust, or GMP); no per-language rationals.
- Effort: a one-off rewrite of the Dart engine (the Dart code becomes a second implementation or is retired), then thin bindings; Dart hooks make FFI consumption supported and stable [@darthooks]; Rust's `bundled` pattern shows the amalgamation-style distribution [@rusqlite]. Browser: compile the same core to WASM (SQLite's own route) [@sqlite2026wasm].
- Distribution: native binaries per OS/arch, wheels for Python, prebuilds for Node; heavier than pure packages, mitigated by WASM fallback.
- Hermetic fit: strong at runtime (single deterministic core, no host calls); build-time native toolchain is the cost.
- Risk: abandons the Dart core as the source of truth. A handle-based ABI (as SQLite's) avoids the stack-ownership pitfalls a Lua-style stack ABI would expose [@lua54manual].

**(C) Dart core compiled to WASM.**
- Determinism: strong (one codebase), but the artefact is a WasmGC module that needs a JS host; it does not run in wasmtime or wasmer today [@dartwasm]. Standalone mode exists only as experiment [@wasmdart; @dartsdk56366].
- Effort: low for the Dart side; high and uncertain for hosts: Python, Rust and Go would need a WasmGC-capable runtime with Dart's host imports, which the sources show is unfinished.
- Distribution: good for TypeScript and browsers; poor for Python and Rust now.
- Hermetic fit: good in principle. Verdict: viable only for the JS/browser channel (also `dart compile js`), not as the universal route in 2026.

**(D) Engine as subprocess with JSON (`cx --json`).**
- Determinism: strong (one engine); numbers must travel as decimal strings or numerator/denominator pairs, since JSON and JS numbers lose big integers [@mdnbigint].
- Effort: lowest; already exists in part (the CLI has JSON-related output modules).
- Distribution: needs a Dart-compiled `cx` binary on the host (`dart compile exe` is shipped [@dartcompile]); process spawn latency makes it unsuitable for tight loops, no in-process binding API, awkward in browsers and mobile.
- Hermetic fit: acceptable (process boundary), but it is a protocol, not an embedding. Best as the immediate integration and as a conformance-test driver for other engines.

#### Recommendation

1. Treat the language specification and a language-neutral conformance corpus (program text, bindings, expected exact results, expected error ids) as the product, in the SQLite TH3/SLT spirit and the CEL/JSON-Schema pattern. Generate expected results from the Dart engine initially, then cross-validate independent engines against each other (the SLT idea) [@sqlite2026slt; @celspec; @jsonschematestsuite]. Confidence: high.
2. Freeze a SQLite-shaped API contract (compile/prepare, bind by name, step/run, typed result accessors, finalize, numeric error codes), documented abstractly so that it can be implemented natively per language or as a C ABI. Do not make bytecode public [@sqlite2026opcode]. Confidence: high.
3. Ship option D now (`cx --json`, with big values as strings) as the universal bridge and test driver; use `dart compile js` or Wasm for the browser channel only if needed. Confidence: medium-high.
4. For the second engine pick Rust, implemented to the shared suite and exposing a handle-based C ABI plus a WASM build; this yields Python, TypeScript (via WASM or napi), Rust and Dart (via hooks and FFI) bindings from one artefact, while Dart remains a native implementation validated by the same suite (a hybrid of A and B). Confidence: medium; it depends on the author's tolerance for maintaining two cores and on how much of the engine surface (matrices, roots, formatting) must be bit-identical.
5. Do not rely on option C as the universal route until Dart ships either a shared-library target or standalone wasm. Re-evaluate when issues #54846 (which #63412 duplicates) or #56366 move [@dartsdk63412; @dartsdk56366]. Confidence: medium (evidence is a snapshot).

## Discussion

SQLite's embeddability is not primarily a feature of C; it is the combination of a minimal object model (connection and statement), a text language as the sole input, an enduring API contract and relentless testing. The bytecode is explicitly private, which means SQLite already behaves like "language plus stable API" in contract terms even though the reference implementation is also the only one used in practice [@sqlite2026opcode; @sqlite2026lts]. The reimplementations show why the contract is hard to clone: Turso, with great investment, still reports gaps, while the cheap clone (modernc) is mechanical translation [@tursocompat; @modernc]. For calculatrix the cloning cost is far lower, because the language is small, results are mathematically defined for exact arithmetic, and the author already has cross-language porting practice. That tilts the balance toward option A, with the conformance suite doing the work SQLite delegates to a single code base. At the same time Dart's inability to export a C ABI removes the cheapest version of option B (keep the Dart core, bind everywhere) and makes the Dart core a dead end for universal embedding unless the SDK changes [@darthooks; @dartsdk63412]. Lua's stack-shaped C API is a pertinent hint: an RPN engine could expose the machine stack directly in a C ABI, but SQLite's statement/column model is safer for a language whose results are matrices [@lua54manual].

Determinism note: because exact rational arithmetic has unique results, cross-engine agreement is testable by equality. Risk concentrates in (i) normalisation and display, (ii) irrational/root handling, (iii) resource limits (`LimitExceededError`), which differ by platform unless defined by the spec as counts, not time or memory, and (iv) floating-point fallbacks, which should be excluded from the conformance surface.

## Conclusion

SQLite shows that a language becomes embeddable through a tiny stable API, a private IR, a stable persisted format and exhaustive tests. Dart cannot currently export that API as a C ABI, so for calculatrix the sustainable route is a conformance-suite-led multi-implementation strategy, with a Rust core (C ABI plus WASM) as the second engine and `cx --json` as the bridge. Confidence: medium overall; high on the Dart constraint as of the evidence date, high on the value of the conformance suite, medium on Rust as the single second core.

## Limitations

- Dart status derives from documentation pages and search snippets; the content of issues #63412, #49035, #61824 and #37480 was only summarised, #63412 was verified with the GitHub CLI on 2026-10-03 (closed as a duplicate of #54846, maintainer comment quoted in Stage 4), but #54846 itself was not read; and no source confirms whether another route (e.g. an undocumented experimental flag) exists in the newest Dart releases.
- Unreachable or uninformative sources: the Dart "js-interop/wasm" page returned HTTP 404 (replaced by dart.dev/web/wasm); cel.dev and cel-spec `tests/simple` returned no implementation list or test-format description; jsonnet.org and the JSON Schema implementations page gave little relevant detail. The CEL multi-language claim is therefore not sourced here.
- better-sqlite3, Go `math/big`, Java `BigInteger` and GMP were not directly retrieved; statements about them are background knowledge.
- The fetch tool summarises pages with a small model; numbers (test counts, version numbers) should be re-checked against the originals before quotation. The Node page indicated "release candidate" status as of v25.7.0 at fetch time.
- The repository was only skimmed; claims about the CLI JSON output rest on file names, not on reading its schema. No benchmarks, no prototype, and no person-hour cost analysis were done.
- Option scores are qualitative judgements.

## References

```bibtex
@misc{sqlite2026amalg,
  title = {The SQLite Amalgamation},
  author = {{SQLite Consortium}},
  year = {2026},
  url = {https://www.sqlite.org/amalgamation.html},
  note = {Accessed 2026-10-03}
}
@misc{sqlite2026testing,
  title = {How SQLite Is Tested},
  author = {{SQLite Consortium}},
  year = {2026},
  url = {https://www.sqlite.org/testing.html},
  note = {Accessed 2026-10-03}
}
@misc{sqlite2026lts,
  title = {Long Term Support},
  author = {{SQLite Consortium}},
  year = {2026},
  url = {https://www.sqlite.org/lts.html},
  note = {Accessed 2026-10-03}
}
@misc{sqlite2026threads,
  title = {Using SQLite in Multi-Threaded Applications},
  author = {{SQLite Consortium}},
  year = {2026},
  url = {https://www.sqlite.org/threadsafe.html},
  note = {Accessed 2026-10-03}
}
@misc{sqlite2026cintro,
  title = {An Introduction To The SQLite C/C++ Interface},
  author = {{SQLite Consortium}},
  year = {2026},
  url = {https://www.sqlite.org/cintro.html},
  note = {Accessed 2026-10-03}
}
@misc{sqlite2026c3ref,
  title = {C-language Interface Object List and Result Codes (c3ref intro)},
  author = {{SQLite Consortium}},
  year = {2026},
  url = {https://www.sqlite.org/c3ref/intro.html},
  note = {Accessed 2026-10-03}
}
@misc{sqlite2026opcode,
  title = {The SQLite Bytecode Engine (VDBE opcodes)},
  author = {{SQLite Consortium}},
  year = {2026},
  url = {https://www.sqlite.org/opcode.html},
  note = {Accessed 2026-10-03}
}
@misc{sqlite2026copyright,
  title = {SQLite Copyright},
  author = {{SQLite Consortium}},
  year = {2026},
  url = {https://www.sqlite.org/copyright.html},
  note = {Accessed 2026-10-03}
}
@misc{sqlite2026wasm,
  title = {SQLite WASM/JS: About},
  author = {{SQLite Consortium}},
  year = {2026},
  url = {https://www.sqlite.org/wasm/doc/trunk/about.md},
  note = {Accessed 2026-10-03}
}
@misc{sqlite2026slt,
  title = {SQL Logic Test},
  author = {{SQLite Consortium}},
  year = {2026},
  url = {https://www.sqlite.org/sqllogictest/doc/trunk/about.wiki},
  note = {Accessed 2026-10-03}
}
@misc{python3sqlite,
  title = {sqlite3 - DB-API 2.0 interface for SQLite databases},
  author = {{Python Software Foundation}},
  year = {2026},
  url = {https://docs.python.org/3/library/sqlite3.html},
  note = {Accessed 2026-10-03}
}
@misc{nodesqlite,
  title = {Node.js: SQLite (node:sqlite)},
  author = {{OpenJS Foundation}},
  year = {2026},
  url = {https://nodejs.org/api/sqlite.html},
  note = {Accessed 2026-10-03}
}
@misc{pubsqlite3,
  title = {sqlite3 package},
  author = {{pub.dev}},
  year = {2026},
  url = {https://pub.dev/packages/sqlite3},
  note = {Accessed 2026-10-03}
}
@misc{rusqlite,
  title = {rusqlite: Ergonomic wrapper for SQLite},
  author = {{rusqlite contributors}},
  year = {2026},
  url = {https://github.com/rusqlite/rusqlite},
  note = {Accessed 2026-10-03}
}
@misc{tursorepo,
  title = {Turso Database: a Rust rewrite of SQLite},
  author = {{Turso}},
  year = {2026},
  url = {https://github.com/tursodatabase/turso},
  note = {Accessed 2026-10-03}
}
@misc{tursocompat,
  title = {Turso SQLite compatibility (COMPAT.md)},
  author = {{Turso}},
  year = {2026},
  url = {https://github.com/tursodatabase/turso/blob/main/COMPAT.md},
  note = {Accessed 2026-10-03}
}
@misc{modernc,
  title = {modernc.org/sqlite: CGo-free port of SQLite},
  author = {{modernc.org}},
  year = {2026},
  url = {https://pkg.go.dev/modernc.org/sqlite},
  note = {Accessed 2026-10-03}
}
@misc{lua54manual,
  title = {Lua 5.4 Reference Manual, section 4: The Application Program Interface},
  author = {Ierusalimschy, Roberto and de Figueiredo, Luiz Henrique and Celes, Waldemar},
  year = {2026},
  url = {https://www.lua.org/manual/5.4/manual.html#4},
  note = {Accessed 2026-10-03}
}
@misc{celspec,
  title = {Common Expression Language specification},
  author = {{Google}},
  year = {2026},
  url = {https://github.com/google/cel-spec},
  note = {Accessed 2026-10-03}
}
@misc{cellangdef,
  title = {CEL Language Definition},
  author = {{Google}},
  year = {2026},
  url = {https://github.com/google/cel-spec/blob/master/doc/langdef.md},
  note = {Accessed 2026-10-03}
}
@misc{jsonschematestsuite,
  title = {JSON-Schema-Test-Suite},
  author = {{JSON Schema Organization}},
  year = {2026},
  url = {https://github.com/json-schema-org/JSON-Schema-Test-Suite},
  note = {Accessed 2026-10-03}
}
@misc{jsonnet,
  title = {Jsonnet - The Data Templating Language},
  author = {{Google}},
  year = {2026},
  url = {https://jsonnet.org/},
  note = {Accessed 2026-10-03; little relevant detail retrieved}
}
@misc{re2repo,
  title = {RE2: a regular expression library},
  author = {{Google}},
  year = {2026},
  url = {https://github.com/google/re2},
  note = {Accessed 2026-10-03}
}
@misc{darthooks,
  title = {Hooks (build hooks and native assets)},
  author = {{Dart team}},
  year = {2026},
  url = {https://dart.dev/tools/hooks},
  note = {Accessed 2026-10-03}
}
@misc{dartcompile,
  title = {dart compile},
  author = {{Dart team}},
  year = {2026},
  url = {https://dart.dev/tools/dart-compile},
  note = {Accessed 2026-10-03}
}
@misc{dartwasm,
  title = {WebAssembly (Wasm) compilation},
  author = {{Dart team}},
  year = {2026},
  url = {https://dart.dev/web/wasm},
  note = {Accessed 2026-10-03}
}
@misc{dartsdk63412,
  title = {Feature request: compile Dart code to a dynamic library (dart-lang/sdk issue 63412)},
  author = {{dart-lang/sdk contributors}},
  year = {2026},
  url = {https://github.com/dart-lang/sdk/issues/63412},
  note = {Accessed 2026-10-03}
}
@misc{dartsdk49035,
  title = {Dart Compile To Dynamic link library (dart-lang/sdk issue 49035) and related issues 37480, 61824},
  author = {{dart-lang/sdk contributors}},
  year = {2022},
  url = {https://github.com/dart-lang/sdk/issues/49035},
  note = {Seen via search results only}
}
@misc{dartsdk56366,
  title = {[proposal] [dart2wasm] Wasm component model / WASI support (dart-lang/sdk issue 56366)},
  author = {{dart-lang/sdk contributors}},
  year = {2024},
  url = {https://github.com/dart-lang/sdk/issues/56366},
  note = {Accessed 2026-10-03}
}
@misc{dartnativeext,
  title = {Native extensions for the standalone Dart VM},
  author = {{Dart team}},
  year = {2026},
  url = {https://dart.dev/server/c-interop-native-extensions},
  note = {Accessed 2026-10-03}
}
@misc{dartpragmas,
  title = {VM-Specific Pragma Annotations},
  author = {{Dart team}},
  year = {2026},
  url = {https://github.com/dart-lang/sdk/blob/main/runtime/docs/pragmas.md},
  note = {Accessed 2026-10-03}
}
@misc{wasmdart,
  title = {wasm.dart: Tools to run Dart in any WebAssembly runtime},
  author = {Moore, Kevin},
  year = {2026},
  url = {https://github.com/kevmoo/wasm.dart},
  note = {Accessed 2026-10-03}
}
@misc{pyfractions,
  title = {fractions - Rational numbers},
  author = {{Python Software Foundation}},
  year = {2026},
  url = {https://docs.python.org/3/library/fractions.html},
  note = {Accessed 2026-10-03}
}
@misc{numrational,
  title = {num-rational crate documentation},
  author = {{Rust num contributors}},
  year = {2026},
  url = {https://docs.rs/num-rational/latest/num_rational/},
  note = {Accessed 2026-10-03}
}
@misc{mdnbigint,
  title = {BigInt - JavaScript reference},
  author = {{MDN contributors}},
  year = {2026},
  url = {https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt},
  note = {Accessed 2026-10-03}
}
```
