# Specifying, Implementing and Tooling a Small Language: A Guide for Evolving cx's RPN (Issue #92)

## Abstract

cx (calculatrix) is a Dart CLI calculator whose RPN is today a token sequence evaluated in order; issue #92 proposes turning it into a language with a compiler. This report synthesizes public language specifications, implementation texts and tool documentation to recommend (a) an architecture (lexer, parser, AST, static checks, tree-walking interpreter), (b) a specification format with executable examples and conformance suites, (c) a modern tooling set (formatter, REPL, structured diagnostics, highlighting/LSP, trace, executable docs), (d) a table of execution limits, and (e) a backward-compatible phased plan from v0.17 to v1.0 and beyond. The recommendation is a tree-walking interpreter over an immutable AST, a spec whose examples run in CI, and a frozen regression corpus as the invariant across all phases [@nystrom_scanning; @nystrom_bytecode; @test262; @celspec]. The limit values proposed are orientative and unmeasured.

## Research Question

How should a small language be specified, implemented and tooled today, and in what backward-compatible phases should cx's RPN evolve (issue #92)?

## Scope and Constraints

In scope: pipeline architecture, specification format, conformance testing, developer tooling, execution limits, and a phased plan for cx. Context: cx is a monorepo (`code/core`, `code/cli`) whose RPN is a token sequence evaluated in order.

Out of scope: new web research beyond the sources below, benchmarking, and implementation. Constraints: backward compatibility with every program valid today; the engine already provides a stack, rollback and a digit limit [@repo_rpn_engine; @repo_machine; @repo_exact]. Success criterion: each recommendation is traceable to a source or to an observation of the repository.

## Method (Staged Protocol)

On 2026-10-03 a Sonnet subagent ran web searches and page fetches and read the cx repository. The fetched pages were read in full; the Starlark specification page could not be read (GitHub returned only navigation). This report is a reformatting, in English, of that subagent's Spanish source report, done by a second agent without new research; it adds no claims. Statements about Starlark come from the subagent's prior knowledge and are unverified. All web sources were accessed 2026-10-03.

## Findings by Stage

### Stage 1 - Problem Framing

The question splits into five sub-questions: architecture, specification, conformance suites, tooling, and limits plus phasing. Boundaries: a calculator-scale language with stack-based syntax and nested blocks (`if...end`, `<< >>`, `for...next`), not a general-purpose language. Repository observations that frame the problem: `RpnEngine` (231 lines) holds a stack of `Matrix` with `push/pop/pick/roll/drop` and `restore(snapshot)` [@repo_rpn_engine]; `CalculatrixMachine.execute` rolls the stack back if a command fails, and `dup/swap/over/rot` are already RPN definitions (macros) over `pick/roll` [@repo_machine]; `ExactArithmetic` already enforces a digit limit (D55) [@repo_exact]. Per-command atomicity and a number-size limit therefore already exist.

### Stage 2 - Source Discovery

Twelve sources were collected: two chapters of *Crafting Interpreters* [@nystrom_scanning; @nystrom_bytecode], the Lua 5.4 manual [@lua54], the CEL language definition [@celspec], the WebAssembly specification [@wasmspec; @wasmvalid], the Starlark spec [@starlark], test262's interpretation guide [@test262], Factor's stack-effect documentation [@factor], rustc's JSON diagnostics [@rustcjson], `dart format` [@dartformat], the Language Server Protocol site [@lsp], and the petitparser package [@petitparser].

### Stage 3 - Source Triage

All sources are primary (specifications, official documentation or the author's book) and relevant to one sub-question each. The Starlark spec was retained as a reference of format but its content is unverified, so no recommendation depends on it. The WebAssembly core specification was only partly verified [@wasmspec].

### Stage 4 - Evidence Extraction

**Lexer.** A token is type plus lexeme plus literal plus line; scanning uses "maximal munch"; comments are consumed without producing tokens; error reporting is centralized rather than scattered through the scanner [@nystrom_scanning].

**Tree versus bytecode.** The book moves from jlox (AST) to clox (bytecode) for performance ("achingly slow"), at the cost of complexity [@nystrom_bytecode].

**Parser libraries.** `petitparser` for Dart is a composable, debuggable alternative [@petitparser].

**Static stack effects.** Factor declares effects `( a b -- c )`, and for non-inline words only the number of inputs and outputs matters [@factor]. WebAssembly validates the stack sequentially, with "stack-polymorphic" instructions (`unreachable`, `br`) whose type is left unconstrained [@wasmvalid].

**Specification formats.** Lua 5.4: a manual in 9 sections (concepts, language, API, ...) with the grammar in "extended BNF" where `{a}` means zero or more and `[a]` optional, keywords in bold [@lua54]. CEL: a grammar using `|`, `[]`, `{}`, `()`; deterministic evaluation to a value or an error; explicit error semantics (`no_matching_overload`); safety and termination guarantees; complexity stated abstractly [@celspec]. WebAssembly: formal validation and execution rules (partly verified) [@wasmspec]. Starlark: a single `spec.md`, a deterministic Python dialect (unverified) [@starlark].

**Conformance.** test262 uses files with YAML frontmatter between `/*---` and `---*/`, with `negative: {phase: parse|resolution|runtime, type}` for cases that must fail, plus `flags` and `includes` [@test262].

**Tooling.** `dart format` is opinionated, with almost no options ("don't decide") [@dartformat]. rustc's JSON diagnostic has `level`, `message`, `code`, `spans` (byte_start/end, 1-based line/column, `is_primary`, `label`), `children` (notes/help) and `suggestion_applicability` (MachineApplicable / MaybeIncorrect / HasPlaceholders) [@rustcjson]. LSP is the editor-server protocol for completion, go to definition, hover and diagnostics, one server for many editors [@lsp].

**Limits.** CEL: an embeddable language declares verifiable bounds and is deterministic [@celspec]. Lua documents concrete limits and distinct error states [@lua54].

### Stage 5 - Synthesis and Limits

#### 5.1 Architecture

Recommended pipeline: lexer, parser, AST, static checks, execution (interpretation, based on [@nystrom_scanning; @nystrom_bytecode]).

Recommendation: a tree-walking interpreter over the AST, without bytecode, at least until v1.x. Reasons (interpretation, supported by the repository observations and [@nystrom_bytecode]):

1. The dominant cost is exact arithmetic (rationals, roots, matrices with big integers), not instruction dispatch, so a VM would not speed it up.
2. A stack language is already close to bytecode: the AST is a flat list of nodes with nested blocks, and walking it is cheap.
3. An engine with stack, rollback and limits already exists; reusing it is the shortest backward-compatible path [@repo_rpn_engine; @repo_machine; @repo_exact].
4. Bytecode is only justified by loops of millions of iterations or a need to serialize programs; neither is a requirement today. Keep the door open: an immutable AST with the interpreter as its only consumer.

Parser: hand-written recursive descent, since the RPN grammar is almost regular (words, literals, delimited blocks). `petitparser` is a composable, debuggable alternative [@petitparser], but adds a dependency and worsens fine-grained error messages; for about 15 productions, write it by hand (judgement of the source report).

Static stack-effect check: following Factor and WebAssembly [@factor; @wasmvalid], check only arity and per branch: each `if` branch must leave the same depth; loops have net effect 0 or a declared one; data-dependent cases (for example `n roll` with variable `n`) are treated as unknown; no types are invented until non-numeric values exist. This is a lint that informs, not full typing; the final truth remains `RpnStackUnderflowError` at run time.

Confidence: medium-high for the tree-walking choice (reasoned from the repo and the book, not measured); medium for the hand-written parser.

#### 5.2 Specification

Format: EBNF grammar plus normative prose plus examples, as in Lua, CEL and WebAssembly [@lua54; @celspec; @wasmspec].

Proposed structure of `docs/spec/calculatrix_rpn_language.md`: (1) lexical structure, (2) EBNF, (3) values and types, (4) informal operational semantics ("state = stack + names; each node transforms the state", one rule per construct), (5) errors and codes, (6) limits, (7) HP 50g table, (8) example programs. Every rule carries examples that are tests.

Examples as tests: a single case format `program => final stack | error with position`. A runner reads the spec's blocks (```` ```rpn ```` with `=> 4 5`) and runs them in CI, so the spec cannot diverge.

#### 5.3 Conformance suites

Adapt test262's frontmatter model [@test262]: `tests/conformance/*.rpn` with a header comment (`# expect: ...` or `# negative: phase=parse code=unbalanced-block`). The key lesson from test262 is the error **phase** (lexer / parser / static / run time) [@test262]. Complement with golden tests (output of `fmt`, of errors, and of `--json` against `.golden` files, regenerable with a flag).

#### 5.4 Tooling

- **Canonical formatter.** `dart format` is the model [@dartformat]. `cx fmt` prints a single form (one space, block indentation, comments preserved) with testable properties `fmt(fmt(x)) == fmt(x)` and `eval(fmt(x)) == eval(x)`. This requires the lexer to keep comments as trivia.
- **REPL.** A session already exists; add persistent definitions, `:stack`, `:words`, `:help word`, and use the same parser (incomplete input such as `<<` without `>>` asks for continuation instead of failing).
- **Errors with position and suggestion.** Following rustc [@rustcjson]: error = `{code, message, token, line, column, length, hint}`; `--json` exposes the same fields; the suggestion "did you mean `dup`?" (edit distance over the registry) is `MaybeIncorrect`. cx already ends errors with a `--help` hint; the next step is the source line with `^^^` underline.
- **LSP / highlighting.** LSP is the editor-server protocol [@lsp]. For cx: first a TextMate grammar (`.tmLanguage.json`) for highlighting; a minimal LSP (diagnostics plus hover with each word's stack effect) only once the parser returns ranged errors and recovers after the first.
- **Debugger / stack trace.** `cx eval --trace` prints `token | stack` after each token; `--step` pauses; in `--json`, an array of events `{pos, token, stack}`. Nearly free because the interpreter already executes token by token with stack snapshots (`restore`) [@repo_rpn_engine]. Add call depth.
- **Executable documentation.** `cx commands show` already documents words; extend it to user words (a comment before the definition is its doc) and dump the documentation examples into the test suite.

#### 5.5 Execution limits

Principle from CEL and Lua [@celspec; @lua54]. All limits configurable by flag with a stable, documented default. The values are orientative, to be calibrated with a benchmark.

| Limit | Suggested default | Error |
|---|---|---|
| Steps (tokens executed, including loop bodies and calls) | 1 000 000 | `limit-steps` |
| Call depth | 200 | `limit-call-depth` |
| Data stack depth | 10 000 | `limit-stack-depth` |
| Number size (digits; D55 already exists) | the D55 value [@repo_exact] | `limit-digits` |
| Wall-clock time | 10 s (optional, non-deterministic) | `limit-time` |
| Program size / block nesting | 1 MB / 100 | `limit-source` |

Reporting rules: (1) a limit is a normal error with its own code, the position of the token that triggered it, and the hint "raise it with `--max-steps N`"; (2) same rollback as today: the stack returns to its pre-command state [@repo_machine]; (3) deterministic limits (steps, depth) are preferred over the time limit, which is only a safety net and is reported separately; (4) static limits (size, nesting) are checked before execution; (5) `--json` includes `limit`, `value`, `max`. An `iferr` must not be able to catch `limit-*`, or a `while` that catches errors would never terminate (reasoning in the source report).

## Discussion

The sources agree on a small set of practices: a position-carrying front end [@nystrom_scanning], a normative grammar with explicit error semantics [@lua54; @celspec], failure cases tagged with their phase [@test262], a single canonical formatter [@dartformat], and structured diagnostics [@rustcjson]. They differ in scale (WebAssembly's formal rules versus Lua's prose manual), and cx should adopt the lighter, prose-and-examples end. The repository already contains the hard parts of a safe runtime (stack snapshots, per-command rollback, a number-size limit), so most work is a front end and tooling around it rather than a new runtime [@repo_rpn_engine; @repo_machine; @repo_exact]. The main risk is the stack-effect lint: WebAssembly and Factor show that sequential arity checks are tractable [@factor; @wasmvalid], but data-dependent words (`n roll`) must stay "unknown" or the lint produces false errors.

## Conclusion

Use a tree-walking interpreter over an immutable AST, a prose-and-EBNF spec whose examples run in CI, test262-style conformance files with a phase-tagged `negative` header, and rustc-style structured diagnostics. Phase the work as follows.

**Transversal invariant:** a frozen regression corpus with every program valid today and its output stack, which must pass identically in every version. New tokens would today yield `unknown-word`, so no valid program changes. Words valid today (the registry, `pi e i`) cannot be redefined, and a user name cannot coincide with them.

| Version | Content | Test named in advance |
|---|---|---|
| v0.17 Frontend | Lexer/parser/AST with positions (line, column); the evaluator consumes the AST with no semantic change; errors with span; comments (`#` to end of line, validated in the 4 shells) | frozen corpus identical; `negative` cases per phase |
| v0.18 Base tooling | `--trace`; idempotent `cx fmt`; `--json` with structured diagnostics; step and stack limits; conformance format | `fmt(fmt(x))==fmt(x)`; error golden |
| v0.19 Names | name literal, `store`/`recall`/`purge`, session globals; static check of unknown names before execution | `unknown-name` before anything runs |
| v0.20 Programs and functions | `<< >>` as a value, `eval`, user-defined words, recursion with call-depth limit, libraries with repeated `--file` | recursive factorial; `limit-call-depth` |
| v0.21 Control flow | `if/then/else/end`, `start/next`, `for`, `while`, comparisons and booleans; per-branch arity lint | quadratic, Newton, matrix sum |
| v0.22 Locals | `-> a b << >>` with lexical scope | shadowing and lifetime of locals |
| v0.23 Errors | `iferr` or `execute` that leaves an error value; `limit-*` not catchable | caught singular-matrix |
| v1.0 | frozen spec, public conformance suite, TextMate grammar, language version separate from the CLI version | executable spec in CI |
| post-1.0 | minimal LSP; bytecode only with performance data | a benchmark that justifies it |

The order respects the one suggested in #92 (comments, names, programs, control, locals, errors); the only addition is placing the AST front end and tooling (trace, fmt, errors with spans) before functions, because everything later depends on reliable positions and on being able to debug. Each phase is an issue with its spec section updated, conformance tests and entries in the frozen corpus; none closes without its spec examples running in CI. Confidence: medium; the plan is a reasoned synthesis, not validated by implementation.

## Limitations

- The Starlark specification page could not be read (GitHub returned only navigation); anything about Starlark is unverified [@starlark].
- The WebAssembly core specification was only partly verified [@wasmspec].
- The article by matklad on LSP was found to be a 404 and was not used.
- The limit values in the table are orientative and unmeasured; they need calibration with a benchmark.
- The tree-walking and hand-written-parser recommendations are reasoned from the book and the repository, not measured.
- Repository observations come from a single read on 2026-10-03 and may change.
- The report is a reformatting of an earlier report; no new research was done in this step.

## References

```bibtex
@misc{nystrom_scanning,
  author={Nystrom, Robert},
  title={Crafting Interpreters: Scanning},
  note={Accessed: 2026-10-03},
  url={https://craftinginterpreters.com/scanning.html}
}

@misc{nystrom_bytecode,
  author={Nystrom, Robert},
  title={Crafting Interpreters: A Bytecode Virtual Machine},
  note={Accessed: 2026-10-03},
  url={https://craftinginterpreters.com/a-bytecode-virtual-machine.html}
}

@misc{lua54,
  author={Ierusalimschy, Roberto and de Figueiredo, Luiz Henrique and Celes, Waldemar},
  title={Lua 5.4 Reference Manual},
  note={Accessed: 2026-10-03},
  url={https://www.lua.org/manual/5.4/manual.html}
}

@misc{celspec,
  author={{Google}},
  title={Common Expression Language: Language Definition},
  note={Accessed: 2026-10-03},
  url={https://github.com/google/cel-spec/blob/master/doc/langdef.md}
}

@misc{wasmspec,
  author={{WebAssembly Community Group}},
  title={WebAssembly Specification, Core},
  note={Accessed: 2026-10-03},
  url={https://webassembly.github.io/spec/core/}
}

@misc{wasmvalid,
  author={{WebAssembly Community Group}},
  title={WebAssembly Specification: Validation of Instructions},
  note={Accessed: 2026-10-03},
  url={https://webassembly.github.io/spec/core/valid/instructions.html}
}

@misc{starlark,
  title={Starlark Language Specification},
  note={Accessed: 2026-10-03. Page content not verified},
  url={https://github.com/bazelbuild/starlark/blob/master/spec.md}
}

@misc{test262,
  author={{TC39}},
  title={test262: Interpreting test262 tests (INTERPRETING.md)},
  note={Accessed: 2026-10-03},
  url={https://github.com/tc39/test262/blob/main/INTERPRETING.md}
}

@misc{factor,
  title={Factor documentation: Stack effect declarations},
  note={Accessed: 2026-10-03},
  url={https://docs.factorcode.org/content/article-effects.html}
}

@misc{rustcjson,
  title={The rustc book: JSON Output},
  note={Accessed: 2026-10-03},
  url={https://doc.rust-lang.org/rustc/json.html}
}

@misc{dartformat,
  title={dart format},
  note={Accessed: 2026-10-03},
  url={https://dart.dev/tools/dart-format}
}

@misc{lsp,
  author={{Microsoft}},
  title={Language Server Protocol},
  note={Accessed: 2026-10-03},
  url={https://microsoft.github.io/language-server-protocol/}
}

@misc{petitparser,
  title={petitparser package},
  note={Accessed: 2026-10-03},
  url={https://pub.dev/packages/petitparser}
}

@misc{repo_rpn_engine,
  title={calculatrix repository: RpnEngine},
  note={File code/core/lib/src/rpn/rpn_engine.dart; read 2026-10-03}
}

@misc{repo_machine,
  title={calculatrix repository: CalculatrixMachine},
  note={File code/core/lib/src/machine/calculatrix_machine.dart; read 2026-10-03}
}

@misc{repo_exact,
  title={calculatrix repository: ExactArithmetic},
  note={File code/core/lib/src/exact/exact_arithmetic.dart; read 2026-10-03}
}
```
