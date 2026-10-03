# Stack and Concatenative Languages: State of the Art for the Design of cx

## Abstract

This report surveys how stack and concatenative languages (Forth, HP RPL, Joy, Factor, Cat/Kitten/Mlatu, PostScript, dc, Uiua, Porth, min, Retro) solve five design problems: comments, definitions, local variables, control flow and stack effects. The goal is to decide which style fits cx, a Dart CLI calculator with an RPN stack language (exact rationals, big integers, matrices) used by humans and LLM agents, which today has no comments, variables, functions, loops or conditionals. The evidence is a web search run on 2026-10-03; only search results were used, with no full-page fetch. The survey shows a trend toward quotations instead of immediate words, declared and checked stack effects, lexical locals and canonical formatters [@factorQuotations; @factorEffects; @factorLocals; @aplwikiUiua]. The recommendation is a hybrid: quotations as values with control as ordinary words, Forth/Factor-style definitions with a declared effect, RPL-style arrow locals, `#` comments, and a formatter. Confidence is medium: the sources are mostly documentation and wiki pages, and several claims are unverified.

## Research Question

How do modern stack/concatenative languages solve comments, definitions, locals, control flow and stack effects, and which style fits cx?

## Scope and Constraints

**Context.** cx (calculatrix) is a Dart CLI calculator with a stack RPN language: exact rationals, big integers, matrices, and the words `dup swap over rot pick roll drop`. It has no comments, variables, functions, loops or conditionals. It is used by humans and LLM agents.

**In scope.** Comment syntax, definition syntax, locals, control flow, stack-effect declaration and checking, plus the neighbouring concerns that surfaced in the sources (modules, debugging, formatters).

**Out of scope.** Implementation cost beyond a coarse qualitative rating, performance, and any new empirical measurement. No code was run.

**Success criteria.** Each of the five problems has at least one documented solution per language family, and the final recommendation is traceable to the evidence.

**Constraints.** Only web search results from a single session (2026-10-03) were available. Claims the original investigation marked as its own knowledge are labeled *(unverified)* throughout and listed in Limitations.

## Method (Staged Protocol)

1. A Sonnet subagent ran a web search on 2026-10-03 on the topic. It produced a Spanish source report with per-language notes, a comparison table, examples, and a recommendation. It used search results only; no page was fetched in full.
2. This document is a reformatting of that report, in English, into the paper-style structure of the `research` skill. No new research was done and no new claims were added. The URLs listed in the source were turned into BibTeX entries; titles and authors in those entries were inferred from the URLs and from the source text, not re-checked.
3. The source did not map each sentence to a specific URL; it listed URLs per language section. In this report each claim is cited with the keys of its section's sources, so a citation means "supported by the section's listed sources as reported", not a verified sentence-level match.

## Findings by Stage

### Stage 1 - Problem Framing

The question was split into five sub-questions: (1) comments, (2) definitions and modules, (3) locals and stack juggling, (4) control flow, (5) stack effects and error reporting. A sixth, cross-cutting question is which combination suits a calculator used by both humans and LLM agents. The relevant criteria are: a regular parser without compilation modes, human readability, few syntactic forms (for LLMs), avoidance of stack juggling, effect verification, extensibility over matrices, implementation cost in Dart, and familiarity for HP-calculator users.

### Stage 2 - Source Discovery

Sources found by search, grouped by language family. Specifications and official documentation: the Forth 2012 locals standard [@forthStdLocals; @forth200xLocals; @nocrewLocals], the Gforth manual [@gforthControl], Factor documentation [@factorEffects; @factorLocals; @factorFry; @factorQuotations]. Papers and manuals: Thun's Joy paper [@thun2001], the Cat paper [@diggins2008], the Factor DLS paper [@factorDls], HP manuals [@hpcalcUserRPL; @hpManual]. Wikis, tutorials and blogs: [@wikiRPL; @edspiRPL3; @joyTutorial; @joyForth; @factorBlog2007; @kittenWiki; @concatUiua; @aplwikiUiua; @uiuaChangelog; @deepwikiUiua; @porthWiki; @retroWiki; @catGithub; @mlatuGithub; @minLang]. Discussion threads: [@clfThread; @hnThread; @concatRevision3534].

### Stage 3 - Source Triage

The source report did not record explicit scores or drop decisions. Reconstructed from the types of source: standards and official language documentation are the most credible for syntax facts (Forth locals, Factor effects and locals); papers for Joy, Cat and Factor design rationale; wiki and aggregator pages (concatenative.org, DeepWiki, APL Wiki) are secondary; discussion threads [@clfThread; @hnThread] are opinion evidence for the stack-juggling problem and are treated as interpretation, not fact. PostScript and dc rest on no listed source; min rests on one homepage URL [@minLang] for part of its claims. Those items are marked *(unverified)*.

### Stage 4 - Evidence Extraction

#### Forth (ANS 94 / Forth 2012)

- **Comments**: `( text )` inline and `\` to end of line. They are words that read the input stream, not syntax. [@forthStdLocals; @gforthControl]
- **Functions**: `: name ... ;`. A flat dictionary; the standard has no modules (only `WORDLIST`). [@forthStdLocals; @gforthControl]
- **Variables/locals**: `VARIABLE`/`VALUE` are global. Forth 2012 standardizes locals as `{: a b | c -- r :}`: arguments are initialized from the stack (the top goes to the rightmost name), `|` separates uninitialized locals, and whatever follows `--` is ignored (it works as an effect comment). Names ending in `:`, `[` or `^` are reserved. [@forthStdLocals; @forth200xLocals; @nocrewLocals]
- **Control**: *immediate* words that compile jumps (`IF ELSE THEN`, `BEGIN UNTIL/WHILE REPEAT`, `DO LOOP`). They only work inside definitions and use a control stack. Powerful, but it creates two modes (interpretation and compilation). [@gforthControl]
- **Errors**: `ABORT"`, `CATCH/THROW`. No stack checking; the typical failure is a silent overflow or underflow. [@forthStdLocals; @gforthControl]

#### HP RPL (HP 48/50g, User RPL / System RPL)

- **Comments**: User RPL has none inside the program on the calculator (discarded strings or PC tools are used). [@wikiRPL; @hpcalcUserRPL]
- **Functions**: a program is an object `« ... »` stored with `'NAME' STO`. Programs are first-class data, like lists, strings, symbols and matrices. [@wikiRPL; @hpManual]
- **Locals**: `→ a b « a b + »` (lexically scoped to the block; they do not appear in the VAR menu) or `→ a b 'a+b'` with an algebraic expression. [@hpcalcUserRPL; @edspiRPL3]
- **Control**: keyword syntax parsed as a block: `IF..THEN..ELSE..END`, `start end FOR i .. NEXT/STEP`, `WHILE..REPEAT..END`, `DO..UNTIL..END`, `IFTE`. These are syntax, not combinators. [@hpcalcUserRPL; @edspiRPL3]
- **Errors/debugging**: `IFERR..THEN..END`, `DOERR`; `DBUG`/`SST` for stepping. Directories (`CRDIR`) act as modules. [@hpManual; @hpcalcUserRPL]

#### Joy (Manfred von Thun)

- No lambdas: only *quotation* `[ ... ]` and concatenation. Combinators unquote. Programs are lists (homoiconic). [@thun2001; @joyTutorial]
- **Control**: `[if] [then] [else] ifte`, `while`, `times`, `map`, `fold`, and anonymous recursion with `linrec`, `binrec`, `genrec`, `primrec`. [@joyTutorial; @joyForth]
- **Definition**: `DEFINE n == ...;`. **Locals**: none. **Comments**: `(* *)`. [@joyTutorial]
- Lesson: excellent for algebraic reasoning; `linrec` and its relatives are hard to read. [@thun2001] (interpretation)

#### Factor (Slava Pestov)

- **Functions**: `: name ( a b -- c ) ... ;`. The effect is mandatory and the compiler **verifies it by inference**; it also serves as documentation. Comments are `!` and `( )`. [@factorEffects]
- **Control**: only quotations plus combinators (`if`, `when`, `unless`, `each`, `map`, `times`, `while`, `bi`, `tri`, `cleave`, `spread`). The user does not write immediate control words. [@factorQuotations; @factorDls]
- **Locals**: `::` and `[| a b | ... ]`, lexical and with closures. It is cited that about 1% of Factor code uses them: the idea is to prefer combinators. *Fry* (`'[ _ + ]`) fills holes in a quotation with stack values. [@factorLocals; @factorFry; @factorBlog2007]
- **Modules**: vocabularies (`USING:`/`IN:`). **Debugging**: listener, inspector, tracebacks. [@factorDls]

#### Cat, Kitten, Mlatu (static typing)

- **Cat** (Diggins, 2008): Joy-style with a Hindley-Milner type system for stack effects and full inference. It shows that inferring stack types is feasible. [@catGithub; @diggins2008]
- **Kitten** (Jon Purdy): typed concatenative with effects/permissions, locals, infix operators and a traditional tokenizer; no active development since about 2018. [@kittenWiki]
- **Mlatu**: a typed descendant on the BEAM VM. [@mlatuGithub]

#### PostScript and dc

- **PostScript** *(unverified, own knowledge)*: `%` comments; `/n { ... } def` (procedures are executable arrays, in effect quotations); control with combinators (`if`, `ifelse`, `for`, `repeat`); `stackunderflow`/`typecheck` errors catchable with `stopped`.
- **dc** *(unverified, own knowledge)*: arbitrary-precision RPN; `#` comments; macros as strings `[ ... ]` run with `x`; registers `sa`/`la`; conditional `>a`. Compact and write-only, but evidence that exact arithmetic in RPN is a real need.

#### Uiua (Kai Schmidt, 2023)

- Stack plus arrays. Primitives use Unicode glyphs (`.` dup, `:` flip, `◌` pop) that can also be typed by ASCII name; the **formatter** converts names to glyphs on save/run. User names start with a capital letter; comments are `#`; `F ← ...` defines; modifiers (`⍚ ≡`) act as combinators; *signatures* are checked at compile time. It is the closest to a calculator with matrices. [@aplwikiUiua; @uiuaChangelog; @concatUiua; @deepwikiUiua]
- Parts of this entry (naming rules, `#` comments, `F ← ...`) were not tied to a verified page by the source and are *(partly unverified, own knowledge)*.

#### Porth, min, Retro, others 2020-2026

- **Porth** (Tsoding, 2021): compiled, strongly typed Forth; **checks the stack at compile time**. Control with keywords `if/else/end`, `while/do/end` (RPL style). [@porthWiki]
- **min** (Fabio Cevasco): quotations `[ ]`, symbols, operator typing, `require`/`load` *(unverified, own knowledge)*. [@minLang]
- **Retro** (Charles Childers): minimalist Forth with quotations and combinators; syntax prefixes instead of a compile mode. [@retroWiki]
- Trend 2020-26 (interpretation by the source): quotations instead of immediates, verified effects, lexical locals, formatter/lint.

#### Resolution table

| Language | Comments | Definition | Locals | Control | Verified effects | Modules |
|---|---|---|---|---|---|---|
| Forth | `( )`, `\` | `: n .. ;` | `{: a b :}` | immediates | no | wordlists |
| RPL | almost none | `« »` STO | `→ a b « »` | keywords `IF..END` | no | directories |
| Joy | `(* *)` | `n == ..;` | no | combinators | no | basic |
| Factor | `!`, `( )` | `: n ( a -- b ) ;` | `::`, `[| |]` | quotations | yes, inferred | vocabularies |
| Cat/Kitten | yes | yes | Kitten yes | combinators | yes, HM | yes |
| PostScript *(unverified)* | `%` | `/n {} def` | dictionaries | procs + ops | runtime | no |
| dc *(unverified)* | `#` | macros | registers | `>r` | no | no |
| Uiua | `#` | `F ← ..` | `⟜ ⊸` | modifiers | signatures | yes |
| Porth | `//` | `proc` | no | `end` keywords | yes, compile time | `include` |

Table sources: the per-language sections above and their citations. Rows for PostScript and dc carry no source.

#### Known problems and solutions

1. **Stack juggling** (`rot rot swap over`). Many languages end up adding locals because some algorithms are awkward without variables; Forth advice is one-line words and no more than about 3 arguments. Solutions: (a) lexical locals (Forth 2012, Factor `::`, RPL `→`, Kitten); (b) preservation combinators (`dip`, `keep`, `bi`, `cleave`); (c) factoring into small words. [@clfThread; @hnThread; @concatRevision3534]
2. **Write-only code**: commented and checked effects (Factor, Uiua), a canonical formatter (Uiua), readable names. [@factorEffects; @aplwikiUiua]
3. **Stack errors far from their origin**: what worked was verifying the declared effect (Factor, Porth, Cat). In an interactive calculator a runtime error that shows the stack and the offending word is enough (the source's own judgment). [@factorEffects; @porthWiki; @diggins2008]
4. **Compile/interpret modes (Forth)**: quotations remove them; everything is a word that consumes a quotation. [@gforthControl; @factorQuotations]
5. **Dense combinators (`linrec`)**: offer `if/times/while/each/map/fold` and avoid the generic recursive ones. [@thun2001]

#### Examples: factorial and quadratic

Input `a b c` on the stack; output `x1 x2`.

**Forth**
```forth
: fact ( n -- n! )  1 swap 1+ 1 ?do i * loop ;
: roots ( a b c -- x1 x2 )
  {: a b c :}  b negate  b b *  4 a * c * -  sqrt  {: nb d :}
  nb d + 2 a * /   nb d - 2 a * / ;
```
**RPL**
```
« 1 SWAP FOR i i * NEXT » 'FACT' STO      @ requires a prior accumulator (1 SWAP)
« → a b c « b NEG b SQ 4 a * c * - √ → nb d « nb d + 2 a * / nb d - 2 a * / » » » 'ROOTS' STO
```
**Factor (quotations + locals)**
```factor
: fact ( n -- n! ) [ 1 ] [ dup 1 - fact * ] if-zero ;
:: roots ( a b c -- x1 x2 )
    b neg  b sq 4 a * c * - sqrt :> d  :> nb
    nb d + 2 a * /  nb d - 2 a * / ;
```
**Proposed hybrid for cx** (no modes, declared effects, arrow locals). Note: the quotation delimiter `[ ]` shown here is kept from the original; see the Discussion, because in cx `[ ]` is already the matrix literal.
```
# factorial
def fact (n -- n!)  [ 1 ] [ dup 1 - fact * ] if0 ;
# roots (exact rationals)
def roots (a b c -- x1 x2)
  -> a b c [
    b neg  b 2 ^  4 a * c * -  sqrt -> nb d [
      nb d + 2 a * /    nb d - 2 a * /
    ]
  ] ;
```
The exact syntax is a proposal; `if0`, `->` and `def` do not exist in cx today. The Forth, RPL and Factor examples are the source's own code and were not run.

### Stage 5 - Synthesis and Limits

**Agreements across sources.** Modern languages (Factor, Retro, min, Kitten, Uiua) converge on quotations as values, lexical locals, declared effects and a formatter [@factorQuotations; @factorLocals; @retroWiki; @kittenWiki; @aplwikiUiua] (confidence: medium; min is unverified). Locals are used sparingly where combinators exist (about 1% of Factor code) but are the standard answer to stack juggling in formulas [@factorBlog2007; @factorLocals] (medium).

**Conflicts and trade-offs.** RPL keyword control is readable and familiar to HP users but adds grammar; quotations reach the same result with one rule [@hpcalcUserRPL; @factorQuotations]. Forth immediates are powerful but create two modes [@gforthControl]. Static inference (Cat, Factor) is feasible but heavier than a calculator needs [@diggins2008; @factorEffects].

**Comparison and recommendation inputs.**

| Criterion | Forth-style | RPL-style | Quotations (Joy/Factor) | Recommended hybrid |
|---|---|---|---|---|
| Regular parser (no modes) | low | medium | high | high |
| Human readability | medium | high | medium | high |
| LLM friendliness (few syntactic forms) | medium | medium | high | high |
| Avoiding juggling | `{: :}` | `→` very good | `::` | `->` |
| Effect verification | no | no | optional | declared + runtime |
| Extensibility (map/each over matrices) | low | medium | high | high |
| Cost in Dart | low | medium | medium | medium |
| HP-calculator familiarity | low | high | low | medium-high |

These ratings are the source's qualitative judgments, not measurements (confidence: low-medium).

**Recommendation: a hybrid, not a copy of one language.**
1. **Quotation core** `[ ... ]` as values, and control as ordinary words (`if`, `when`, `times`, `while`, `each`, `map`, `fold`, `range`). No compile mode and no immediates: one parser, fewer cases for an LLM agent.
2. **Forth/Factor-style definition** with a declared effect, `def n (a b -- c) ... ;`. First version: runtime check with an error showing the stack and the word. Static inference only if needed (Cat and Factor show it is feasible).
3. **RPL arrow locals** `-> a b [ ... ]`, lexical and closing over quotations: the best answer to stack juggling in formulas. Keep `dup swap over rot pick roll` for simple cases.
4. **Comments** `#` to end of line (simple for shell and LLM) and an effect comment in `def`.
5. **Errors and debugging**: message with stack before/after, `--trace` per step, and `.s`. Explicit type errors (no float coercion), which is the distinctive value of exact rationals.
6. **Modules**: defer; `use "file.cx"` or a user prelude is enough.
7. **Formatter/lint** (inspired by Uiua): canonical code, useful for agents.
8. From RPL take the idea of objects (lists, matrices, programs as values) and locals, but not block keywords (`IF THEN ELSE END`), which add grammar that quotations solve with a single rule.

**Why not pure Forth**: compile mode and immediates are the hardest part to explain and implement and add nothing to a calculator. **Why not pure RPL**: larger keyword grammar, no comments or effects. **Why not something entirely new**: Factor, min, Retro, Kitten and Uiua converge on the same elements (quotations, lexical locals, declared effects, formatter); innovating outside them is risk without evidence. [@factorQuotations; @factorLocals; @factorEffects; @kittenWiki; @aplwikiUiua; @retroWiki; @minLang]

## Discussion

**Delimiter clash in cx.** In cx, `[ ]` is already the matrix literal syntax. The hybrid's quotation delimiter therefore has to be a different one, for example `{ }` as in PostScript *(PostScript usage unverified)*. The examples above keep the original `[ ]` and should be read with that substitution: for instance `def fact (n -- n!)  { 1 } { dup 1 - fact * } if0 ;` and `-> a b c { ... }`. This note is an adaptation for cx, not a claim from the sources. The choice also leaves room for a matrix literal inside a quotation without ambiguity.

**Fit with cx.** The evidence supports a small, regular grammar for a tool used by LLM agents: a single construct (quotation) for code-as-value, ordinary words for control, and one binding form (`->`) [@factorQuotations; @factorLocals]. Declared effects offer documentation and an error source that is closer to the origin; the cheapest useful form for an interactive calculator is a runtime check [@factorEffects; @porthWiki]. Exact rationals make explicit type errors (no float coercion) a natural fit; dc is cited as evidence that exact RPN arithmetic is a real need *(dc unverified)*.

**Convergence as evidence.** The argument against inventing a new style rests on convergence among several recent languages. This is indirect evidence: it shows what others settled on, not that it works best for cx. The source's own ratings in the comparison tables are judgments, and the recommendation inherits that uncertainty.

## Conclusion

For comments, definitions, locals, control and stack effects, the surveyed languages offer: `#`/`!`/`%`/`( )` comments; `: n ( effect ) ... ;` or `def`-like definitions; lexical locals (`{: :}`, `::`, `→`); control by immediates, keywords, or quotation combinators; and effects either unchecked (Forth, RPL), inferred (Factor, Cat) or checked by signature (Uiua, Porth). The best fit for cx is the hybrid described above: quotations plus ordinary control words, `def` with a declared effect checked at runtime first, RPL-style arrow locals, `#` comments, trace and debug aids, a formatter, and deferred modules. The quotation delimiter must not be `[ ]` because of the matrix literal. Confidence: medium.

## Limitations

- **Search-only evidence.** Only web search results were used on 2026-10-03; no page was fetched in full. Quotations, syntax details and the claims below were not checked against the full text of the pages.
- **Unverified claims (own knowledge of the source's author, not checked):** PostScript (comments, `def`, `if`/`ifelse`/`for`/`repeat`, `stopped`); dc (comments, macros, registers, conditionals); min (`[ ]` quotations, symbols, operator typing, `require`/`load`; only the homepage URL is listed); parts of Uiua (naming rules, `#` comments, `F ← ...` definitions, glyph details). The corresponding table rows (PostScript, dc) are also unverified. These should be checked before being cited elsewhere.
- **Citation granularity.** The source listed URLs per language section, not per sentence. Citations here point to the section's sources as a group; a given sentence may be supported by only some of them.
- **Bibliographic metadata.** Titles and authors in the References were inferred from the URLs and the source text and were not verified; entries where the author is unknown use the site or project name. The Factor DLS paper's author list is not given in the source.
- **No link check.** No URL was visited, so broken or unreachable links are not flagged; none is known to be broken.
- **Dated or inactive sources.** Kitten has had no active development since about 2018 [@kittenWiki]. The HP manuals and the 2007 Factor blog post are old.
- **Interpretive content.** The criteria ratings in the comparison tables, the claim that quotations solve what keywords solve "with a single rule", and the "trend 2020-26" are the source's judgments, not measured results. The sources on stack juggling are discussion threads [@clfThread; @hnThread].
- **Code not executed.** The Forth, RPL, Factor and hybrid examples were not run; the hybrid does not exist in cx.
- **Reformatting.** This document was rewritten from a Spanish source report; any translation error is mine. The cx delimiter note in the Discussion is an addition requested for this document and has no source.

## References

```bibtex
@misc{forthStdLocals,
  title={Forth 2012 Standard: Locals, brace-colon word},
  author={{Forth Standard}},
  url={https://forth-standard.org/standard/locals/bColon},
  note={Accessed: 2026-10-03}
}

@misc{forth200xLocals,
  title={Forth 200x: Locals proposal},
  author={{Forth200x}},
  url={http://www.forth200x.org/locals.html},
  note={Accessed: 2026-10-03}
}

@misc{nocrewLocals,
  title={Forth 2012: Locals},
  author={{lars.nocrew.org}},
  url={http://lars.nocrew.org/forth2012/locals.html},
  note={Accessed: 2026-10-03}
}

@misc{gforthControl,
  title={Gforth manual: Arbitrary control structures},
  author={{Gforth project}},
  url={https://gforth.org/manual/Arbitrary-control-structures.html},
  note={Accessed: 2026-10-03}
}

@misc{wikiRPL,
  title={RPL (programming language)},
  author={{Wikipedia}},
  url={https://en.wikipedia.org/wiki/RPL_(programming_language)},
  note={Accessed: 2026-10-03}
}

@misc{hpcalcUserRPL,
  title={User RPL programming (hpcalc.org community document)},
  author={{HP Calculator Archive}},
  url={https://literature.hpcalc.org/community/prog-userrpl.pdf},
  note={Accessed: 2026-10-03}
}

@manual{hpManual,
  title={HP calculator manual (document c02836298)},
  organization={Hewlett-Packard},
  url={https://h10032.www1.hp.com/ctg/Manual/c02836298.pdf},
  note={Accessed: 2026-10-03}
}

@misc{edspiRPL3,
  title={RPL Programming Tutorial, Part 3},
  author={{Eddie Shore}},
  year={2011},
  url={http://edspi31415.blogspot.com/2011/10/rpl-programming-tutorial-part-3-hp.html},
  note={Accessed: 2026-10-03. Author inferred from blog name}
}

@inproceedings{thun2001,
  title={Joy: Forth's Functional Cousin},
  author={von Thun, Manfred},
  booktitle={EuroForth 2001},
  year={2001},
  url={http://www.euroforth.org/ef01/thun01.pdf},
  note={Accessed: 2026-10-03}
}

@misc{joyTutorial,
  title={Joy tutorial (j01tut)},
  author={{Hypercubed}},
  url={https://hypercubed.github.io/joy/html/j01tut.html},
  note={Accessed: 2026-10-03}
}

@misc{joyForth,
  title={Joy and Forth},
  author={{Hypercubed}},
  url={https://hypercubed.github.io/joy/html/forth-joy.html},
  note={Accessed: 2026-10-03}
}

@misc{factorEffects,
  title={Factor documentation: Stack effect declarations},
  author={{Factor project}},
  url={https://docs.factorcode.org/content/article-effects.html},
  note={Accessed: 2026-10-03}
}

@misc{factorLocals,
  title={Factor documentation: locals vocabulary},
  author={{Factor project}},
  url={https://docs.factorcode.org/content/vocab-locals.html},
  note={Accessed: 2026-10-03}
}

@misc{factorFry,
  title={Factor documentation: Fry},
  author={{Factor project}},
  url={https://docs.factorcode.org/content/article-fry.html},
  note={Accessed: 2026-10-03}
}

@misc{factorQuotations,
  title={Factor documentation: Quotations},
  author={{Factor project}},
  url={https://docs.factorcode.org/content/article-quotations.html},
  note={Accessed: 2026-10-03}
}

@inproceedings{factorDls,
  title={Factor: a dynamic stack-based programming language (DLS paper)},
  author={{Factor authors (author list not verified)}},
  year={n.d.},
  url={https://factorcode.org/littledan/dls.pdf},
  note={Accessed: 2026-10-03}
}

@misc{factorBlog2007,
  title={Named local variables and lexical closures},
  author={Pestov, Slava},
  year={2007},
  url={http://factor-language.blogspot.com/2007/08/named-local-variables-and-lexical.html},
  note={Accessed: 2026-10-03. Author inferred from blog name}
}

@misc{catGithub,
  title={Cat language repository},
  author={Diggins, Christopher},
  url={https://github.com/cdiggins/cat-language},
  note={Accessed: 2026-10-03}
}

@article{diggins2008,
  title={Cat: a typed functional stack-based language (Diggins 2008)},
  author={Diggins, Christopher},
  year={2008},
  url={https://dcreager.net/remarkable/Diggins2008b.pdf},
  note={Accessed: 2026-10-03. Exact title not verified}
}

@misc{kittenWiki,
  title={Kitten},
  author={{concatenative.org}},
  url={https://concatenative.org/wiki/view/Kitten},
  note={Accessed: 2026-10-03}
}

@misc{mlatuGithub,
  title={Mlatu language repository},
  author={{mlatu-lang}},
  url={https://github.com/mlatu-lang/mlatu},
  note={Accessed: 2026-10-03}
}

@misc{aplwikiUiua,
  title={Uiua},
  author={{APL Wiki}},
  url={https://aplwiki.com/wiki/Uiua},
  note={Accessed: 2026-10-03}
}

@misc{uiuaChangelog,
  title={Uiua changelog},
  author={{Uiua project}},
  url={https://github.com/uiua-lang/uiua/blob/main/changelog.md},
  note={Accessed: 2026-10-03}
}

@misc{concatUiua,
  title={Uiua},
  author={{concatenative.org}},
  url={https://concatenative.org/wiki/view/Uiua},
  note={Accessed: 2026-10-03}
}

@misc{deepwikiUiua,
  title={Introduction to Uiua},
  author={{DeepWiki}},
  url={https://deepwiki.com/uiua-lang/uiua/1.1-introduction-to-uiua},
  note={Accessed: 2026-10-03}
}

@misc{porthWiki,
  title={Porth},
  author={{concatenative.org}},
  url={https://concatenative.org/wiki/view/Porth},
  note={Accessed: 2026-10-03}
}

@misc{minLang,
  title={min programming language},
  author={{min-lang.org}},
  url={https://min-lang.org},
  note={Accessed: 2026-10-03}
}

@misc{retroWiki,
  title={Retro},
  author={{concatenative.org}},
  url={https://www.concatenative.org/wiki/view/Retro},
  note={Accessed: 2026-10-03}
}

@misc{clfThread,
  title={comp.lang.forth discussion thread on stack juggling},
  author={{comp.lang.forth}},
  url={https://groups.google.com/g/comp.lang.forth/c/rp7sdVsREGc/m/myrEJjsxoCQJ},
  note={Accessed: 2026-10-03}
}

@misc{hnThread,
  title={Hacker News discussion thread (item 3582261)},
  author={{Hacker News}},
  url={https://news.ycombinator.com/item?id=3582261},
  note={Accessed: 2026-10-03}
}

@misc{concatRevision3534,
  title={concatenative.org wiki page, revision 3534},
  author={{concatenative.org}},
  url={https://concatenative.org/wiki/revision/3534},
  note={Accessed: 2026-10-03}
}
```
