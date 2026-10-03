# Language Design Principles and Evolution Practices for Growing cx from an RPN Calculator into a Small Modern Language

## Abstract

This report surveys classic texts, concrete design principles, evolution processes and well-known design mistakes in programming-language design, and distills them into 15 actionable recommendations for cx (calculatrix), a Dart command-line calculator with a stack-based RPN language. The evidence comes from web search and page fetches on 2026-10-03 and from unverified recall. Sources that were read directly (PEP 20, Pike, Zig, the Rust edition guide) support the strongest conclusions. The classic texts on growth, simplicity and reasoning (Steele, Wirth, Dijkstra) are cited from memory and are labeled as such. The main conclusion is to write a specification and grammar first, keep a minimal orthogonal core, extend the language through user-definable words, forbid implicit coercions and hidden effects, make errors the primary product (including a machine-readable form for LLM agents), and evolve through lightweight proposals, per-file language versions and an executable conformance suite [@hoare1973hints; @pep20; @pike2012less; @zig2026overview; @rustedition].

## Research Question

Which programming-language design principles and evolution practices should guide turning cx's RPN into a small modern language?

## Scope and Constraints

**Context.** cx is a Dart CLI calculator with a stack RPN language. It has exact rationals, big integers and matrices. Today it has no comments, variables, functions, loops or conditionals. It is used by humans and by LLM agents.

**In scope.** Classic design texts, concrete principles, language-evolution processes, and famous design mistakes, as they apply to a small stack-based language.

**Out of scope.** Concrete syntax decisions for cx, implementation details in Dart, and performance.

**Success criteria.** The investigation succeeds if each principle or practice is traceable to a source (or explicitly labeled as unverified or opinion) and leads to an actionable recommendation for cx.

**Labeling convention used throughout.**

- **[V]**: verified in this investigation by reading or querying the source.
- **[M]**: from memory or general knowledge, not verified in this investigation.
- **[O]**: opinion or inference of the investigator about cx.

## Method (Staged Protocol)

The work was done in two steps.

1. On 2026-10-03, a Sonnet subagent ran a web search and page fetches following the staged protocol (framing, discovery, triage, evidence extraction, synthesis). It produced a Spanish-language working report with a [V]/[M]/[O] label on each claim.
2. This document is a reformatting of that working report into English paper structure. No new research was done and no new claims were added. The only permitted extra step was confirming titles or authors for the bibliography.

Consequences for reading this report: the verification level of each claim is exactly as labeled by the subagent. Hoare (1973), Gleam and the null quote were verified only through search results and secondary summaries, not by reading the full source. Several sources could not be retrieved (see Limitations).

## Findings by Stage

### Stage 1 - Problem Framing

The question is normalized as: what should guide a small, stack-based, exact-arithmetic language as it gains variables, functions, loops and conditionals? Four sub-questions were derived: (1) which classic texts give design criteria; (2) which concrete principles follow; (3) which evolution processes keep a language stable while it grows; (4) which famous mistakes should be avoided. Boundaries are those in Scope and Constraints.

### Stage 2 - Source Discovery

Candidate sources, with type:

- Hoare, "Hints on Programming Language Design" (1973), classic paper [@hoare1973hints].
- Steele, "Growing a Language" (OOPSLA 1998), conference keynote [@steele1998growing].
- Wirth (Pascal, Oberon, "A Plea for Lean Software"), classic essays [@wirth_memory].
- Dijkstra, "The Humble Programmer" (1972) and EWDs [@dijkstra_memory].
- PEP 20, "The Zen of Python", community design principles [@pep20].
- Pike, "Less is exponentially more" (2012), designer essay [@pike2012less].
- Zig language overview, official documentation [@zig2026overview].
- Gleam language tour, official documentation [@gleam2026tour].
- Elm, "Compiler Errors for Humans", designer blog post [@elm2015errors].
- Rust compiler diagnostics (`help:`/`note:`) [@rustdiag_memory] and the Rust edition guide, official documentation [@rustedition].
- Hoare's null apology, QCon 2009, via a secondary write-up [@hoare2009null].
- Process practices from memory: PEP/RFC-style proposals [@proposals_memory], SemVer [@semver_memory], test262 [@test262_memory].
- Famous mistakes from memory: JS/PHP coercions [@jscoerce_memory], dynamic scope in early Lisps and JS `var` [@dynscope_memory], Python 2 to 3 [@py23_memory].

### Stage 3 - Source Triage

Triage by verification level:

- **Read directly [V]:** PEP 20, Pike, Zig overview, Rust edition guide [@pep20; @pike2012less; @zig2026overview; @rustedition].
- **Verified only through search results or secondary summary [V partial]:** Hoare 1973 (summary and quotes; the PDF is cited but was not read in full), Gleam (secondary summary), Hoare's null quote (search over his QCon 2009 talk) [@hoare1973hints; @gleam2026tour; @hoare2009null].
- **Not retrievable and kept as [M]:** Steele (PDF could not be extracted), Elm (page could not be extracted), Wirth (404). Dijkstra was not consulted [@steele1998growing; @elm2015errors; @wirth_memory; @dijkstra_memory].

No source was dropped. The [M] sources were retained because they are the canonical references for their ideas, but their claims are stated as unverified.

### Stage 4 - Evidence Extraction

#### 4.1 Classic texts

- **Hoare, "Hints on Programming Language Design" (1973)** [V partial]. Criteria: simplicity, security, fast translation, efficient code, readability. He criticizes substituting modularity for simplicity. Quote: "What would we think of a navigator who wears a life jacket on land and takes it off at sea?", an argument against disabling checks in production. Lesson stated in the working report: checks are not turned off; safety belongs to the language and is not optional [@hoare1973hints].
- **Steele, "Growing a Language" (OOPSLA 1998)** [M]. Thesis: a language should be designed to grow; users should be able to add "words" that look primitive, and the designer must accept that users will build the library. The talk limits itself to monosyllables until each new word is defined, which models gradual learning in its form. This fits almost literally a Forth-like stack language [@steele1998growing].
- **Wirth** (Pascal, Oberon, "A Plea for Lean Software") [M]. Ideas: complexity is the enemy; a language should fit in one's head; every feature has a cost. Verifiable today: Zig defends something analogous, with a PEG grammar of about 580 lines [@wirth_memory; @zig2026overview].
- **Dijkstra** [M]: "The Humble Programmer" (1972) and EWDs on reasoning about correctness: languages in which programs can be reasoned about, and distrust of the ad hoc [@dijkstra_memory].
- **Zen of Python, PEP 20** [V]. Relevant lines: "Explicit is better than implicit"; "Errors should never pass silently. Unless explicitly silenced"; "In the face of ambiguity, refuse the temptation to guess"; "There should be one-- and preferably only one --obvious way to do it"; "If the implementation is hard to explain, it's a bad idea"; "Special cases aren't special enough to break the rules"; "Readability counts" [@pep20].
- **Pike, "Less is exponentially more" (2012)** [V]. "The better you understand, the pithier you can be." "Go is about composition." Few orthogonal pieces that compose [@pike2012less].
- **Zig** [V]: "no hidden control flow, no hidden memory allocations, no preprocessor, and no macros"; the full syntax fits in a PEG grammar of about 580 lines; the goal is to debug your application, not your knowledge of the language [@zig2026overview].
- **Gleam** [V via secondary summary]: one way to define functions, one way to handle errors (Result/Option), no exceptions, no implicit conversions, no null, no macros; small surface [@gleam2026tour].
- **Elm, "Compiler Errors for Humans"** [M; page could not be extracted]. Errors with code context, concrete suggestions and a friendly tone; the reference of the category [@elm2015errors].
- **Rust** [M]: diagnostics with `help:` and `note:`; editions are covered in the process section [@rustdiag_memory].

#### 4.2 Concrete principles

1. **Orthogonality**: few independent primitives that combine without exceptions (Pike, Wirth) [V/M]. Each stack word does one thing and composes with the others [@pike2012less; @wirth_memory].
2. **Consistency, no special cases** (PEP 20) [V] [@pep20].
3. **One obvious way** (PEP 20, Gleam) [V]. Avoid duplicate synonyms [@pep20; @gleam2026tour].
4. **Gradual learning** [M]: a useful subset learnable in minutes; advanced features appear later without changing the earlier ones (Steele). A calculator that remains a calculator if you do not use variables [@steele1998growing].
5. **User extensibility** [M]: define words indistinguishable from primitives (Steele; Forth `: name ... ;`). Corollary: the standard library is written with the same mechanism the user has [@steele1998growing].
6. **No hidden control flow or effects** (Zig) [V]. No word should read files, network or clock without that being visible [@zig2026overview].
7. **Errors as a main product**: where, what was expected, what was found, how to fix it (Elm/Rust) [M]. For LLM agents, additionally: stable structured output, error codes, a hint line [O] [@elm2015errors; @rustdiag_memory].
8. **Determinism** [O]: same input, same output; no implicit randomness or time. Valuable for agents and tests.
9. **Termination and safety**: loops bounded or limited by steps and memory; checks are never disabled (Hoare) [V for the thesis; the limit design is O]. A CLI used by agents must not hang [@hoare1973hints].
10. **Explicit errors over sentinel values**: Result/Option instead of null or silent NaN (Gleam, Hoare) [V] [@gleam2026tour; @hoare2009null].

#### 4.3 Evolution process

- **Written specification and formal grammar**: Zig maintains its PEG grammar as a living document [V] [@zig2026overview]. An EBNF/PEG grammar for cx would force ambiguities to surface before they are implemented [O].
- **Proposals (PEPs/RFCs)** [M]: a short document per change with motivation, rejected alternatives and compatibility [@proposals_memory].
- **Versioning and compatibility** [M]: SemVer; a deprecation policy that warns one version before removal [@semver_memory].
- **Rust editions** [V]: they allow "skin deep" incompatible changes (for example new keywords); each crate chooses its edition privately and editions must interoperate; `cargo fix` migrates automatically. For cx: a language version per file and a `cx migrate` [O] [@rustedition].
- **Conformance suites** [M]: executable examples (program, expected output) independent of the implementation, such as test262 for JavaScript. For cx: `.cx` cases plus expected output as an executable specification and a corpus for agents [O] [@test262_memory].
- **Reserve space** [O]: reserve syntax that is an error today (`:`, `;`, `#`, `{ }`, `"`) for the future.

#### 4.4 Famous mistakes and lessons

- **Null**: Hoare calls it his "billion-dollar mistake", introduced in ALGOL W (1965) "simply because it was so easy to implement" [V via search over his QCon 2009 talk]. Lesson: do not add a "does not exist" value that escapes the type system [@hoare2009null].
- **Implicit coercions in JS/PHP** (`"1"+1`, `[]+{}`, non-transitive `==`) [M]. Lesson: zero implicit conversions; in cx the hierarchy integer, rational, complex, matrix must be documented, not accidental [@jscoerce_memory].
- **Binary floating point as the default number** [M]: cx already avoids it with exact rationals; keep that and make any approximate output explicit [@jscoerce_memory].
- **Dynamic scope and default globals** (early Lisps, JS `var`) [M]. Lesson: lexical scope from the start [@dynscope_memory].
- **Features that do not compose** (C macros, overloading) [M]; Zig and Gleam exclude them [V] [@zig2026overview; @gleam2026tour].
- **Python 2 to 3** [M]: the cost of an incompatible jump without gradual migration; it motivates editions [@py23_memory].

### Stage 5 - Synthesis and Limits

**Agreements.** The directly read sources converge. PEP 20, Pike, Zig and Gleam all favor a small surface, one obvious way, composition and no hidden behavior [@pep20; @pike2012less; @zig2026overview; @gleam2026tour]. Hoare adds that safety checks must never be optional [@hoare1973hints]. The Rust edition guide gives a concrete mechanism for incompatible evolution [@rustedition].

**Tension.** Steele's growth thesis (let users extend) and the Wirth/Zig/Gleam minimalism (fewer features) pull in different directions [@steele1998growing; @wirth_memory; @zig2026overview]. The reconciliation proposed here is the Forth model: keep the core minimal and make extension happen through one mechanism that the standard library also uses [O].

**Confidence per conclusion.**

| Conclusion | Confidence | Rationale |
|---|---|---|
| Small orthogonal core, one obvious way, no hidden control flow or effects | High | Directly read: PEP 20, Pike, Zig [@pep20; @pike2012less; @zig2026overview] |
| Per-file language versions and automated migration (editions model) | High for the Rust mechanism, medium for transfer to cx | Edition guide read directly; applicability to cx is [O] [@rustedition] |
| Checks never disabled; explicit errors over sentinels | Medium | Hoare and Gleam verified only through search results and secondary summary [@hoare1973hints; @gleam2026tour; @hoare2009null] |
| User-defined words as the extension mechanism | Medium | Rests on Steele, retrieved only from memory [@steele1998growing] |
| Elm/Rust-style errors, structured output for agents | Medium for the style, low for the agent-specific design | Elm and Rust from memory; agent aspects are [O] [@elm2015errors; @rustdiag_memory] |
| Determinism, bounded termination limit design, reserved symbols | Low | Opinion of the investigator, no external source |

**Unresolved.** Dijkstra's contribution was not examined, and the exact wording of Steele, Elm and Wirth was not checked (see Limitations).

## Discussion

The evidence supports a consistent picture for cx. Because cx is already a stack language with exact arithmetic, it starts from a position the surveyed sources recommend: a tiny core and no implicit float behavior. The risk is in how it grows. Adding variables, functions, loops and conditionals ad hoc would reproduce the problems catalogued above: special cases, dynamic scope, implicit coercions and hidden effects. The sources suggest that the order of work matters: specification and grammar first, then comments (the cheapest change, and the moment to reserve remaining symbols), then user-defined words, then bounded iteration and conditionals [@zig2026overview; @steele1998growing].

The dual audience (humans and LLM agents) is not addressed directly by any of the classic sources. The working report's position, labeled [O], is that the same principles help both: determinism, stable error codes, a `--json` mode and an executable conformance corpus make the language predictable for agents, and cx's existing `benchmark` work is a natural base for that corpus.

## Conclusion

Fifteen recommendations for cx follow from the findings. Items marked [O] in the evidence are opinions of the investigator and not findings of the cited sources.

1. **Write the specification and an EBNF/PEG grammar before adding variables, functions or control flow**, in the repo and versioned with the CLI [@zig2026overview].
2. **Publish 8-10 own principles** (PEP 20 style) and cite them in every proposal, for example "no hidden magic" and "the error explains and suggests" [@pep20].
3. **Adopt the Forth model for extension**: a `: name body ;` syntax (or another) that creates words indistinguishable from primitives, and write most of the standard library in cx with that mechanism [@steele1998growing].
4. **Minimal orthogonal core**: freeze the stack primitives and require each new word to justify why it cannot be defined in cx [@pike2012less; @wirth_memory].
5. **One way per concept**: one comment style, one conditional, one loop; reject aliases [@pep20; @gleam2026tour].
6. **Add comments now** (for example `#` to end of line): the cheapest change and the moment to reserve the other free symbols [O].
7. **Lexical scope and immutable variables by default**; mutation, if it exists, with visible syntax [@dynscope_memory].
8. **Termination by default**: bounded iteration (`times`, ranges); recursion or a general loop with a configurable step limit and a clear error [@hoare1973hints].
9. **Zero implicit coercions** and a documented table of type promotions; an error instead of guessing [@pep20; @jscoerce_memory].
10. **Elm/Rust-style errors**: position, current stack, expected vs. found, suggestion, stable code; a `--json` mode for agents; keep the `--help` hint line [@elm2015errors; @rustdiag_memory].
11. **Documented determinism**: no I/O, clock or randomness except explicit opt-in words [O] [@zig2026overview].
12. **Language version per file** (a pragma such as `#!cx 1`), one-version deprecation and `cx migrate` if there are breaking changes (Rust editions model) [@rustedition; @semver_memory].
13. **Executable conformance suite**: `.cx` cases with expected output, used as specification, regression and agent evaluation corpus (continuing the `benchmark` line) [@test262_memory].
14. **Lightweight proposal process**: one short file per change (motivation, alternatives, compatibility, impact on agents) [@proposals_memory].
15. **A proper name, without haste**: separate the language brand from the CLI (`cx` can remain the CLI); settle it when the grammar and conformance suite exist [O].

## Limitations

- **Unreachable or unextractable sources.** The Steele PDF (`cs.virginia.edu`) could not be extracted, so its content is cited from memory [@steele1998growing]. The Elm page could not be extracted, so its content is cited from memory [@elm2015errors]. The Wirth source returned a 404, so Wirth is cited from memory [@wirth_memory]. Dijkstra was not consulted [@dijkstra_memory].
- **Partial verification.** Hoare 1973, Gleam and the null quote were verified only through search results or a secondary summary, not by reading the primary source in full [@hoare1973hints; @gleam2026tour; @hoare2009null].
- **Memory-based claims.** Every claim marked [M] (Rust diagnostics, proposal processes, SemVer, test262, JS/PHP coercions, dynamic scope, Python 2 to 3) was not verified in this investigation. The bibliography entries for these have no URL and are placeholders for sources to be fetched later.
- **Opinion.** Claims marked [O] are inferences for cx, not findings of the cited sources.
- **Process.** The research was done by a single subagent in one session, and this report is a reformatting; there was no independent second reading of the sources.

## References

Entries without a URL (`*_memory` keys) mark claims cited from memory that were not retrieved.

```bibtex
@misc{hoare1973hints,
  title={Hints on Programming Language Design},
  author={Hoare, C. A. R.},
  year={1973},
  url={https://rebelsky.cs.grinnell.edu/Courses/CS302/2007S/Readings/hoare-design.pdf},
  note={Accessed: 2026-10-03. Verified partially via search results and quotes}
}

@inproceedings{steele1998growing,
  title={Growing a Language},
  author={Steele, Guy L.},
  booktitle={OOPSLA 1998 (invited talk)},
  year={1998},
  url={https://www.cs.virginia.edu/~evans/cs655/readings/steele.pdf},
  note={Accessed: 2026-10-03. PDF could not be extracted; content cited from memory}
}

@misc{pep20,
  title={PEP 20 -- The Zen of Python},
  author={Peters, Tim},
  year={2004},
  url={https://peps.python.org/pep-0020/},
  note={Accessed: 2026-10-03}
}

@misc{pike2012less,
  title={Less is exponentially more},
  author={Pike, Rob},
  year={2012},
  url={https://commandcenter.blogspot.com/2012/06/less-is-exponentially-more.html},
  note={Accessed: 2026-10-03}
}

@misc{zig2026overview,
  title={Zig Language Overview},
  author={{Zig Software Foundation}},
  url={https://ziglang.org/learn/overview/},
  note={Accessed: 2026-10-03}
}

@misc{gleam2026tour,
  title={The Gleam Language Tour},
  author={{Gleam project}},
  url={https://tour.gleam.run/everything/},
  note={Accessed: 2026-10-03. Verified via secondary summary}
}

@misc{elm2015errors,
  title={Compiler Errors for Humans},
  author={Czaplicki, Evan},
  url={https://elm-lang.org/news/compiler-errors-for-humans},
  note={Accessed: 2026-10-03. Page could not be extracted; content cited from memory}
}

@misc{rustedition,
  title={The Rust Edition Guide: Editions},
  author={{The Rust Project}},
  url={https://doc.rust-lang.org/edition-guide/editions/index.html},
  note={Accessed: 2026-10-03}
}

@misc{hoare2009null,
  title={Tony Hoare apologizes for inventing the null reference},
  author={Limoncelli, Tom},
  year={2009},
  url={https://everythingsysadmin.com/2009/01/tony-hoare-apologizes-for-inve.html},
  note={Accessed: 2026-10-03. Secondary write-up about Hoare's QCon 2009 talk, found via search}
}

@misc{wirth_memory,
  title={Pascal, Oberon and "A Plea for Lean Software"},
  author={Wirth, Niklaus},
  note={Cited from memory, not retrieved (source returned 404 during the investigation)}
}

@misc{dijkstra_memory,
  title={The Humble Programmer (1972) and EWD notes},
  author={Dijkstra, Edsger W.},
  note={Cited from memory, not consulted}
}

@misc{rustdiag_memory,
  title={Rust compiler diagnostics (help/note messages)},
  author={{The Rust Project}},
  note={Cited from memory, not retrieved}
}

@misc{proposals_memory,
  title={Language change proposal processes (PEPs, RFCs)},
  note={Cited from memory, not retrieved}
}

@misc{semver_memory,
  title={Semantic Versioning and deprecation policies},
  note={Cited from memory, not retrieved}
}

@misc{test262_memory,
  title={test262, the ECMAScript conformance test suite},
  note={Cited from memory, not retrieved}
}

@misc{jscoerce_memory,
  title={Implicit coercions in JavaScript and PHP; binary floating point as default number},
  note={Cited from memory, not retrieved}
}

@misc{dynscope_memory,
  title={Dynamic scope in early Lisps and JavaScript var},
  note={Cited from memory, not retrieved}
}

@misc{py23_memory,
  title={The Python 2 to 3 transition},
  note={Cited from memory, not retrieved}
}
```
