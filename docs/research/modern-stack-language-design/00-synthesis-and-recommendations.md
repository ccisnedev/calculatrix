# From RPN to a Modern Stack Language for cx: Synthesis and Recommendations

## Abstract

cx (calculatrix) evaluates RPN programs over exact rationals, big integers and matrices, but its language has no comments, names, functions, loops or conditionals. Issue #92 proposes growing it into a full language. This synthesis combines four staged investigations in this folder:
- design principles [@cx01principles];
- modern concatenative languages [@cx02concatenative];
- numeric and agent-oriented languages [@cx03numeric];
- specification and implementation [@cx04implementation].

It recommends neither Forth nor RPL as they are. The recommendation is a hybrid that modern stack languages converge on:
- code blocks (quotations) as values;
- control flow as ordinary words;
- definitions with declared stack effects;
- RPL-style arrow locals.

Two additions are specific to cx. A local block may contain an infix expression, reusing `eval infix`. Every program either terminates or exhausts a deterministic step budget. The work is phased so that every RPN program valid today stays valid, and it starts with a front end with source positions and tooling, before functions.

## Research Question

Which language design should cx's RPN evolve into, and in what order, so that it stays minimal, exact, safe and usable by both humans and LLM agents?

## Scope and Constraints

- **In scope:** surface syntax and semantics of the language, numeric policy, execution limits, error reporting, specification method, implementation architecture and the phased plan.
- **Out of scope:**
  - units and dimensions (deferred, see [@cx03numeric]);
  - modules;
  - static type inference;
  - the final name of the language.
- **Constraints from the repo:**
  - `[ ]` is already the matrix literal syntax (`code/core/lib/src/evaluation/literals.dart`) [@cxliterals].
  - A name table with read-only bindings already exists for `pi`, `e` and `i` (`code/core/lib/src/names/name_table.dart`) [@cxnametable].
  - The engine already rolls the stack back when a command fails, and applies a digit limit [@cx04implementation].
- **Success criteria:**
  - one recommended style, with its rationale and rejected alternatives;
  - a principles list;
  - a phase plan compatible with #92;
  - open questions that can be measured.

Reports in this folder:

| File | Question |
|---|---|
| `01-language-design-principles.md` | Principles and evolution practices |
| `02-concatenative-languages.md` | How stack languages solve definitions, locals, control and effects |
| `03-numeric-and-agent-languages.md` | Exact versus approximate numbers, bounded languages, LLM usability |
| `04-specification-and-implementation.md` | Spec format, architecture, tooling, limits, phases |
| `00-synthesis-and-recommendations.md` | This document |

## Method (Staged Protocol)

1. **Investigation.** On 2026-10-03, four Sonnet subagents investigated one sub-question each in parallel, with web search, page fetches and, for report 04, a read of the repo.
2. **Reformatting.** Each report was rewritten into this skill's paper format, with BibTeX references and its own Limitations section.
3. **Synthesis.** The session model (Opus) reconciled the four reports and checked the delimiter and name-table constraints against the repo.
4. **Evidence base.** This synthesis cites the four reports as its sources. Primary sources are cited only where a conclusion rests on them directly.

## Findings by Stage

### Stage 1 - Problem Framing

**Two tensions shape the design:**
- **Minimalism against expressiveness.** Forth's minimalism appeals to the maintainer, but formulas written with pure stack manipulation ("stack juggling") are hard to read for humans and, by hypothesis, for LLMs [@cx02concatenative; @cx03numeric].
- **Exactness against open-ended computation.** Loops and recursion turn the existing digit budget into an insufficient guard [@cx03numeric; @cx04implementation].

### Stage 2 - Source Discovery

The four reports gathered primary sources across four groups:
- **Language and design documents:** PEP 20, Pike on Go, Zig, Rust editions, Factor, Forth 2012 locals, RPL manuals, Uiua, Lua 5.4, CEL, WebAssembly, test262 and rustc JSON diagnostics.
- **Numeric documentation:** Raku numerics, Qalculate, Numbat and fend.
- **Bounded execution:** Wasmtime fuel and Dhall safety guarantees.
- **Agent usability:** Anthropic's guidance on writing tools for agents, and arXiv papers on LLM performance in low-resource languages.

The source lists are in each report's References [@cx01principles; @cx02concatenative; @cx03numeric; @cx04implementation].

### Stage 3 - Source Triage

- **Primary specifications and official documentation** were preferred: Factor, Forth 2012, Lua, CEL, Wasm, test262, rustc, Raku and Qalculate.
- **Weaker sources** are flagged in each report: a forum post for Frink, blog guidance on agent-friendly command-line tools, and search snippets only for report 02.
- **Unreachable or unconsulted** were Steele's paper, Elm's error-message article, Wirth, the Starlark spec and one article on language servers. Claims that depend on them are labeled as coming from memory.

### Stage 4 - Evidence Extraction

| Finding | Evidence | Confidence |
|---|---|---|
| Modern stack languages converge on four pieces: quotations as values, control flow as words that consume quotations, lexical locals, declared or checked stack effects. | Factor, Joy, Retro, min, Kitten, Uiua [@cx02concatenative] | high |
| Forth's compile mode and immediate words are the hardest part to explain and implement; quotations remove the need for them. | [@cx02concatenative] | medium |
| Arrow locals (RPL `→`, Forth 2012 `{: :}`, Factor `::`) are the accepted cure for stack juggling. | [@cx02concatenative] | high |
| RPL's `→ a b 'expr'` binds locals into an algebraic expression. | RPL manuals [@cx02concatenative] | high |
| Silent numeric degradation is the main hazard of exact arithmetic: Raku's `Rat` silently becomes floating point (`Num`) when its denominator overflows. | Raku docs [@cx03numeric] | high |
| Bounded execution is achieved either by restricting the language (Starlark, CEL, Dhall) or by deterministic metering (Wasm fuel, CEL runtime cost). | [@cx03numeric] | high |
| Agents benefit from structured, actionable errors and JSON output. | Anthropic guidance, blog guides [@cx03numeric] | medium |
| LLMs perform worse in languages that are rare in training data (pass@1 7–33% in R and Racket). | arXiv papers on low-resource languages; the figure-to-paper mapping was not rechecked [@cx03numeric] | medium |
| No study measures LLMs writing stack languages. | [@cx03numeric] | n/a |
| A tree-walking interpreter suffices, because exact arithmetic dominates the cost. | Crafting Interpreters, repo reading [@cx04implementation] | medium |
| Executable spec examples and a conformance suite tagged with the phase in which an error must occur (as test262 does) keep the spec and the implementation aligned. | test262, Lua, CEL [@cx04implementation] | high |
| Design principles: explicit before implicit, one obvious way, words defined by the user indistinguishable from primitives, no hidden control flow. | PEP 20, Pike, Zig; Steele from memory [@cx01principles] | high, Steele medium |

### Stage 5 - Synthesis and Limits

**Agreements.**
- **Error reporting.** All four reports independently recommend structured errors that carry a position, the stack and a hint, plus `--json` [@cx01principles; @cx03numeric; @cx04implementation].
- **Comments.** All four recommend `#` line comments as the first and cheapest change.

**Conflicts.**
1. **Shape of control flow.**
   - Report 04's phase plan uses RPL block keywords (`if/then/else/end`, `start/next`), following the current text of #92.
   - Report 02 recommends quotations with combinator words, on the grounds that one grammar rule replaces many keywords.
   - This synthesis sides with report 02. The parser gets one mode instead of keyword blocks, an agent has fewer syntactic forms to learn, and users can write new control words in the language itself, as Steele's principle asks [@cx01principles; @cx02concatenative].
2. **Delimiter for quotations.**
   - Report 02 writes quotations as `[ ]`, but in cx `[ ]` already means a matrix [@cxliterals].
   - `{ }` is free in the RPN syntax and has precedent in PostScript.
   - RPL's `« »` is not plain ASCII, and `<< >>` is easy to misread as comparison operators.
3. **An infix layer.**
   - Report 03 suggests an infix syntax alongside RPN for agents. A whole second language for control flow would contradict "one obvious way".
   - The narrow version is RPL's: infix only as the body of an arrow local, reusing the existing `eval infix` evaluator. This keeps one control-flow syntax while removing stack juggling from formulas.

## Discussion

### Recommended language shape

| Concern | Recommendation | Precedent |
|---|---|---|
| Comments | `#` to end of line | dc, Uiua |
| Code as a value | `{ ... }` quotation | Joy, Factor, PostScript |
| Control flow | words: `if`, `ifelse`, `times`, `each`, `while` | Factor, PostScript |
| Definitions | `: name ( a b -- c ) ... ;`, effect declared, checked at run time | Forth, Factor |
| Locals | `-> a b c { ... }`, lexical | RPL `→` |
| Formulas | `-> a b c '(-b + sqrt(b^2 - 4*a*c)) / (2*a)'` | RPL `→ a b 'a+b'` |
| Names | bindings in the existing name table; system constants stay read-only | [@cxnametable] |
| Limits | `--max-steps` (deterministic), call depth and stack depth, in addition to `--max-digits` | Wasm fuel, CEL |

Rejected:
- **Forth's compile mode and immediate words:** they create two modes, and the hardest one to explain is the one that adds nothing to a calculator.
- **RPL's keyword blocks:** each keyword is one more grammar rule, and quotations cover them.
- **A wholly new design:** the existing languages converge on the pieces above, and departing from them would be risk without evidence [@cx02concatenative].

Example (proposed syntax, not implemented):

```
# factorial, recursive
: fact ( n -- n! )  dup 1 <= { drop 1 } { dup 1 - fact * } ifelse ;

# quadratic roots, exact where possible
: roots ( a b c -- x1 x2 )
  -> a b c '(-b + sqrt(b^2 - 4*a*c)) / (2*a)'  '(-b - sqrt(b^2 - 4*a*c)) / (2*a)' ;
```

### Principles

These are a draft, in the style of PEP 20, for the spec to adopt:

1. Exact by default. An approximate value is marked and never looks exact again.
2. Nothing degrades silently. Reaching a limit is an error with its own code.
3. There is one obvious way to write each concept.
4. Words defined by the user are indistinguishable from primitives.
5. The base language is deterministic and hermetic: no I/O, clock or randomness.
6. Every program terminates or exhausts a deterministic budget, and a program cannot catch a limit error.
7. An error states where it happened, what was expected, what was found, the stack, and the next step.
8. Every RPN program valid today stays valid.

### Phase plan

This revises the order in #92 [@cx04implementation]:

| Version | Content |
|---|---|
| 0.17 | Front end: lexer, parser and syntax tree with source positions; `#` comments; a frozen regression corpus of today's programs |
| 0.18 | `--trace`, `cx fmt`, JSON errors with source spans, step and stack-depth limits, conformance file format |
| 0.19 | Names in the name table |
| 0.20 | `{ }` quotations, `:` definitions with declared effects, recursion under the call-depth limit |
| 0.21 | Control flow as words; a lint that checks stack depth branch by branch |
| 0.22 | Arrow locals and the infix bridge |
| 0.23 | Errors a program can catch (`limit-*` excluded) |
| 1.0 | Frozen spec, public conformance suite, language version separate from the CLI version |

### What to measure before freezing the syntax

The claim that LLMs write stack code poorly is an untested hypothesis [@cx03numeric]. The repository's benchmark can test it. The same tasks would be given in three styles:
- pure stack;
- locals;
- locals with infix.

The comparison would measure first-attempt success and error recovery. The result decides how prominent the infix bridge should be.

## Conclusion

1. Adopt the hybrid: `{ }` quotations, control flow as words, `: name ( effect ) ... ;`, `-> locals`, `#` comments.
2. Add the infix bridge inside arrow locals. It is cx's distinctive piece, and it reuses an evaluator that already exists.
3. Keep exactness strict, add a deterministic step budget, and make every limit an error that a program cannot catch.
4. Build the front end and the tooling (positions, trace, fmt, JSON errors) before functions and control flow.
5. Write the spec with executable examples and a conformance suite tagged by error phase.
6. Amend #92 to this design: replace the keyword blocks with quotations, change the quotation delimiter, and use the new phase order.
7. Decide the language's name once the grammar and the conformance suite exist. The CLI stays `cx`.

Confidence:
- high for items 3–5;
- medium for items 1 and 6, which rest on convergence across languages rather than measurements;
- low to medium for item 2 until the benchmark measures it.

## Limitations

- **Evidence base.** The synthesis relies on the four reports and inherits their limitations. These include claims from memory about Steele, Elm, Wirth, PostScript, dc, min, Scheme, Julia and Wolfram, and search snippets that were not opened in full for report 02.
- **Proposed syntax.** The proposed syntax has not been prototyped.
- **The `{ }` delimiter.** It has been checked against the RPN literal syntax only, not against the shells cx runs in; quoting `{ }` is safe inside single quotes in POSIX shells and in PowerShell.
- **The single quote in the infix bridge.** It collides with shell quoting when a program is passed inline rather than from a file. Its delimiter is an open question.
- **Limit values.** The default values suggested in report 04 are orientative and need calibration.

## References

```bibtex
@misc{cx01principles,
  title={Language Design Principles for Evolving cx's RPN},
  author={calculatrix project},
  year={2026},
  note={docs/research/modern-stack-language-design/01-language-design-principles.md}
}

@misc{cx02concatenative,
  title={Modern Concatenative Languages: Definitions, Locals, Control Flow and Stack Effects},
  author={calculatrix project},
  year={2026},
  note={docs/research/modern-stack-language-design/02-concatenative-languages.md}
}

@misc{cx03numeric,
  title={Exact and Approximate Numbers, Bounded Languages and LLM-Agent Usability},
  author={calculatrix project},
  year={2026},
  note={docs/research/modern-stack-language-design/03-numeric-and-agent-languages.md}
}

@misc{cx04implementation,
  title={Specifying, Implementing and Phasing a Small Language for cx},
  author={calculatrix project},
  year={2026},
  note={docs/research/modern-stack-language-design/04-specification-and-implementation.md}
}

@misc{cxliterals,
  title={calculatrix core: literal parsing (matrix literal syntax)},
  author={calculatrix project},
  year={2026},
  note={code/core/lib/src/evaluation/literals.dart}
}

@misc{cxnametable,
  title={calculatrix core: name table (issue #70)},
  author={calculatrix project},
  year={2026},
  note={code/core/lib/src/names/name_table.dart}
}
```
