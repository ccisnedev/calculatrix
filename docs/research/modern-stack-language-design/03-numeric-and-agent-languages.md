# Exact vs Approximate Numbers and Agent-Safe Language Design: Lessons for cx

## Abstract

cx (calculatrix) is a Dart CLI calculator with a stack (RPN) language, exact rationals, big integers, matrices and complex numbers, a `--max-digits` limit (10000) and `--json` output. It will grow variables, functions, loops and conditionals, and is used by humans and LLM agents. This report surveys two fronts. Front A covers calculation and numeric languages (Numbat, fend, Qalculate, Frink, Raku, and background knowledge on Scheme, Julia, Wolfram, bc/dc). Front B covers bounded languages (Starlark, CEL, Dhall, Wasmtime fuel) and guidance on making tools usable by LLM agents. The main findings are that silent promotion and silent overflow between exact and approximate types are the dangerous points, as the Raku `Rat` to `Num` degradation shows [@rakuRat; @rakuNumerics]; that a determinism-preserving step budget complements a data-size budget [@wasmtimeInterrupt; @celSpec]; and that structured, actionable errors are the best-supported agent-usability practice [@anthropicTools]. Ten recommendations follow. Claims are tagged [H] (fact backed by the cited source), [O] (opinion or inference) or [M] (prior knowledge not re-verified in this session). No study of LLMs writing stack languages was found, so the claim that the stack is a disadvantage is a hypothesis.

## Research Question

What do calculation languages teach about exact vs approximate numbers, and what do bounded languages and LLM-agent guidance teach about making cx's language safe and usable by agents?

## Scope and Constraints

In scope: numeric semantics (exactness, promotion, overflow, presentation of approximate results) in calculation languages; mechanisms that bound program execution; published guidance on LLM-friendly tools, CLIs and error messages; evidence on LLM performance on low-resource languages. Out of scope: implementing the recommendations, symbolic algebra, and new benchmarking. Constraints: this is a single-day web search (2026-10-03); search snippets were mostly not opened in full; no new research was performed during the final write-up. Convention used throughout: **[H]** fact backed by the cited source; **[O]** opinion or inference; **[M]** prior knowledge not re-verified in this session (official documentation is cited where available).

## Method (Staged Protocol)

1. A Sonnet subagent performed a web search on 2026-10-03 and produced a Spanish-language source report with findings tagged [H]/[O]/[M].
2. That report was then reformatted into this English paper-style document following the staged protocol of the `research` skill. During reformatting no new research was done and no new claims were added; web fetches were used only to confirm titles and authors of arXiv entries for the bibliography.
3. Honest caveat: the staging below (framing, discovery, triage, extraction, synthesis) is a reconstruction of the work presented in protocol order; the original search was not logged stage by stage.

## Findings by Stage

### Stage 1 - Problem Framing

The question splits into two fronts. Front A asks how existing calculation languages treat exact and approximate numbers and which behaviors cx should copy or avoid. Front B asks how to bound a language that will gain loops and functions, and what makes a language or CLI usable by LLM agents. Success criteria: each front yields transferable design decisions that can be stated as actionable recommendations for cx.

### Stage 2 - Source Discovery

Candidate sources were the project repositories and manuals of Numbat, fend, Qalculate and Raku [@numbatRepo; @fend; @qalcMode; @rakuRat]; language specifications and engineering posts for Starlark, CEL, Dhall and Wasmtime [@starlarkSpec; @celSpec; @dhallSafety; @wasmtimeInterrupt]; Anthropic engineering guidance and several blog posts on agent CLIs [@anthropicTools; @devtoCli; @arcjet]; and arXiv papers on LLM code generation for low-resource languages [@giagnorio2025; @cassano2023; @joel2024].

### Stage 3 - Source Triage

Official documentation, specifications and arXiv papers were treated as strong. Blog posts on agent-CLI design [@devtoCli; @arcjet; @kellyErrors; @clispec] are not peer reviewed and are marked as such. The Frink source is a physics forum thread [@frinkPF] and is weak (the official frinklang.org documentation would be preferable). The Hacker News thread used for Insect [@hn14625795] is also informal. A 2026 paper on "no-resource" languages was seen only through its abstract [@giagnorio2026]. The compiler survey cited for static-constraint difficulties relates to stack languages only by analogy [@zhang2026].

### Stage 4 - Evidence Extraction

#### Front A. Calculation and numeric languages

**Numbat.**
- [H] A statically typed language with physical dimensions as types (Length, Time, Force = Mass * Acceleration). `+` requires equal dimensions and inference solves the constraints. Conversion uses `->` (`30 km/h -> mph`). The unit library is written in Numbat itself and is extensible via `init.nbt` [@numbatRepo; @numbatIntro; @numbatFunctions].
- [O] The transferable decision for cx: unit or dimension errors are type errors with a clear message, not a silently wrong result.

**fend.**
- [H] Arbitrary-precision arithmetic over rationals, complex numbers, units and bases 2 to 36. It chooses the output format (exact or approximate) automatically and the user changes it with `to` [@fend].
- [M] It marks approximate results with `approx.` and leaves exact results unmarked. This is the pattern closest to what cx needs.

**Qalculate / qalc.**
- [H] A configurable approximation mode: -1 auto, 0 exact, 1 "try exact" (default), 2 approximate, 3 dual. In exact mode no approximations are computed. It supports interval arithmetic and uncertainty propagation [@qalcMode; @qalcManual].
- [O] An explicit `exact | auto | approx` mode is better than an opaque heuristic, because an agent can pin it and obtain reproducible output.

**Frink.**
- [H] Arbitrary precision, rationals and interval arithmetic to track error. It converts internally to SI units and permits user-defined units [@frinkPF]. (Weak secondary source.)

**Raku (Rat).**
- [H] `0.1 + 0.2 == 0.3` is true because decimal literals are `Rat` (1/10, etc.). A `Rat` denominator is limited to 64 bits. If an operation overflows it, the result **silently degrades to `Num`** (floating point), configurable with `$*RAT-OVERFLOW`. `FatRat` stores numerator and denominator as unbounded integers [@rakuRat; @rakuNumerics; @shitovFatRat].
- [O] A direct precedent for cx's digit-limit problem. Silent degradation is the behavior to avoid: a limit that is hit must produce an error or an explicit mark, not change type unannounced.

**Scheme, Julia, Wolfram, bc/dc, Insect (all [M]).**
- [M] Scheme (R7RS) defines the numeric tower integer, rational, real, complex with an exactness attribute. `(/ 1 3)` gives exact `1/3`, `(sqrt 2)` gives an inexact float, and `exact->inexact` / `inexact->exact` convert. Exactness "infects" toward inexact. (No URL was recorded for this claim.)
- [M] Julia has `Rational{T}` with `//` and `BigInt`. `Int` operations overflow silently (wrap) unless `BigInt` is used, and promotion mixing rational with float gives float. `Rational` with `Int64` can throw `OverflowError` [@julia].
- [M] Wolfram: arithmetic is exact by default (`1/3`, `Sqrt[2]`, `Pi` symbolic) and `N[expr, n]` requests an n-digit approximation. A literal with a decimal point infects to machine precision [@wolframN].
- [M] `bc` uses fixed-scale decimals (`scale`) rather than rationals, and `dc` is the classic stack calculator with registers. Insect (Numbat's predecessor, same author) uses units and floats [@hn14625795].

#### Front B. Bounded languages and agent-oriented design

**Bounded languages.**
- Starlark [H]: deterministic and hermetic. It has no recursion or `while`; `for` loops iterate finite iterables, so execution terminates. No side effects such as file or network I/O [@starlarkSpec; @bazelLang]. There is debate about making recursion optional [@starlark97]. [H] Python-like syntax, which helps LLMs.
- CEL [H]: not Turing-complete, side-effect free, with guaranteed termination. It includes an **estimated cost** subsystem that statically computes the worst case, and a runtime cost that halts evaluation past a limit [@celSpec; @k8sCel].
- Dhall [H]: a total language without general recursion; lists are consumed only through primitives such as `List/fold`. It can still take very long, "but that is less likely by accident" [@dhallSafety; @dhallBlog].
- Wasm fuel [H]: Wasmtime subtracts one unit of fuel per instruction and traps at zero. It is **deterministic** (same input and fuel give the same cut-off point). Epochs (wall-clock based) are cheaper (about 10%) but not deterministic [@wasmtimeInterrupt; @wasmtimeConfig].
- jq, Lua [M]: jq is a functional filter language with JSON output and is Turing-complete through recursion; programs are bounded only from outside. Lua is small and embeddable, and is sandboxed with instruction-count hooks (`debug.sethook`) and by removing libraries.
- Reading [O]: two strategies exist, restricting the language (Starlark, CEL, Dhall) or metering execution (fuel, CEL runtime cost). cx already has a digit budget, a measure of *data size*. A language with loops and functions additionally needs a *step* budget, deterministic like fuel, so the same program fails at the same point on any machine. Wall-clock time is not reproducible.

**What makes a language or CLI usable by an LLM.**
- [H] Anthropic recommends token-bounded responses (pagination, filters, a "concise" format with about a third fewer tokens) and actionable errors instead of cryptic codes or traces. Its example: instead of `TOO_MANY_RESULTS`, "Found 847 expenses... narrow your date range" [@anthropicTools].
- [H, blog sources, not peer reviewed] Guidelines for agent CLIs: JSON on stdout and everything else on stderr, JSON by default when stdout is not a TTY, string error codes (`image_not_found`), distinct exit codes, the offending value included in the error, and a suggested next step [@devtoCli; @arcjet; @kellyErrors; @clispec].
- [H] Languages with little presence in training data perform worse: in R and Racket pass@1 ranges from 7% to 33.1%, and in Julia and Lua from 19.2% to 61.4%; performance rises with the share of training data [@giagnorio2025; @cassano2023; @joel2024]. A 2026 paper on "no-resource" languages was seen only as an abstract [@giagnorio2026].
- [H, indirect] LLMs struggle when a language imposes non-local static constraints (Rust ownership) and generation is open loop with no compiler feedback [@zhang2026] (a survey; the link to RPN is by analogy only).
- No study of LLMs writing Forth, RPN or stack languages was found. [O] The reasonable inference is that the stack is a disadvantage: it requires keeping stack depth "in the head" (a non-local constraint) and there is little training text. This is a hypothesis that cx can test with its own benchmark (the repository already has one, rounds r2 and r3).

### Stage 5 - Synthesis and Limits

**Synthesis of Front A.**
1. [O] Two families exist: exact by default with explicit approximation (Scheme, Wolfram, Raku, fend, Qalculate) and float by default (Julia, Insect, bc). For cx, already based on exact rationals, the first is coherent. Confidence: high for the characterization of the sources checked; medium for Scheme, Wolfram, Julia, Insect and bc, which are [M].
2. [O] The dangerous points are **silent promotion** (Raku `Rat` to `Num`, decimal-literal infection in Wolfram) and **silent overflow** (Julia `Int64`). cx avoids both by having big integers and must keep that property when adding `sqrt`, `exp`, `ln`, etc. Confidence: high for Raku [H], medium for Wolfram and Julia [M].
3. [O] For irrationals the options are a marked approximate type, controlled-precision approximation, or intervals (Frink, Qalculate). The sensible minimum is an approximate value that carries a visible mark and does not "look" exact again after further operations. Confidence: medium.
4. [O] Presentation: exact as a fraction or finite/repeating decimal; approximate with a `≈` prefix or an `exact: false` field in JSON. Confidence: medium (fend's mark is [M]).

**Synthesis of Front B.** Confidence is high that a deterministic step budget is feasible and valued (fuel is deterministic [H]); high that structured actionable errors are recommended (official Anthropic guidance [H]); medium for CLI conventions (blog sources); low for the claim that stack syntax hurts LLMs (hypothesis, no direct evidence).

## Discussion

The sources converge on one theme: failures should be visible and reproducible. Raku's silent `Rat` to `Num` change [@rakuRat] and Julia's wrapping overflow [@julia] hide a loss of exactness or a wrong value, whereas Qalculate's explicit modes [@qalcMode] and Wasmtime's deterministic fuel [@wasmtimeInterrupt] make behavior pinnable by the caller. This matters for agents, who cannot easily notice that a number silently stopped being exact. Bounded-language practice gives cx two paths that can be combined: start with a terminating subset in the style of Starlark/CEL [@starlarkSpec; @celSpec] and add metering for the rest. On agent usability, the strongest evidence is official guidance on actionable errors [@anthropicTools]; the evidence on syntax comes from low-resource-language studies [@giagnorio2025; @cassano2023], which suggest that familiar infix/named syntax may help, but they do not study stack languages. Recommendation 6 and 8 are therefore best read as hypotheses to be checked with cx's own benchmark.

## Conclusion

Ten actionable recommendations for cx (all [O], derived from the evidence above):

1. **Explicit numeric mode** `--numeric exact|auto|approx` (Qalculate style) [@qalcMode]. Default `exact`, because an agent needs determinism.
2. **Never degrade silently.** If an exact result exceeds `--max-digits`, return a structured error (lesson from Raku `Rat` to `Num` [@rakuRat]) with a suggestion (`use approx(x, 30)` or `--max-digits`).
3. **Marked approximate type**: any operation involving an approximate value yields an approximate value; text shows `≈` and JSON shows `"exact": false` and `"digits": n`. No infection by decimal literals (`0.1` is exactly 1/10) [@wolframN].
4. **Deterministic step budget** (`--max-steps`, fuel style [@wasmtimeInterrupt]) in addition to `--max-digits`, and optionally `--max-depth` for calls. The same program and limit give the same failure point, reported in the error. No wall-clock limit in the semantics.
5. **Termination by construction where possible**: finite `for x in <range/list>` first, with `while` and recursion only under budget [@starlarkSpec; @celSpec]. Start with a Starlark/CEL-style subset and widen.
6. **Infix/named syntax layer in addition to RPN** for variables, functions and control flow, close to Python/JS/Scheme (high training frequency [@giagnorio2025]). Keep the stack as a compact mode. Verify with the project's own benchmark by comparing agent success rates for each syntax.
7. **Structured, actionable errors** [@anthropicTools]: `{"error":{"code":"stack_underflow","message":"...","pos":{line,col},"expected":"2 operands, found 1","hint":"..."}}`, with the source fragment and distinct exit codes [@devtoCli; @arcjet]. Reuse the existing final `--help` line.
8. **Stack errors with depth trace**: report the stack state at the failure point (`stack: [3, 1/2]`), which replaces the mental bookkeeping that is costly for LLMs (hypothesis, see Limitations).
9. **JSON by default when stdout is not a TTY**, result on stdout and diagnostics on stderr [@devtoCli; @clispec]. Include in the JSON the type (`int|rat|complex|matrix`), the exact value as a string, steps consumed and maximum digits used, for reproducibility.
10. **Hermeticity and reproducibility**: no I/O, network, clock or unseeded randomness in the base language (as in Starlark [@starlarkSpec]). If units are added (Numbat), treat dimensional errors as type errors [@numbatIntro], as a second phase after variables, functions and loops.

## Limitations

- **[M] claims.** The statements on Scheme, Julia, Wolfram, bc/dc, Insect, jq and Lua, and on fend's `approx.` mark, are prior knowledge not re-verified in this session. Official documentation is cited for Julia and Wolfram, but the Scheme/R7RS, jq, Lua and bc/dc statements carry no recorded source, and the Insect statement rests on an informal discussion thread [@hn14625795].
- **Weak sources.** The Frink claims rest on a physics forum thread [@frinkPF]; the official frinklang.org documentation was not consulted. The agent-CLI guidance comes from blog posts and an informal spec site, not peer-reviewed work [@devtoCli; @arcjet; @kellyErrors; @clispec].
- **Search snippets not opened in full.** Most findings come from search results whose pages were not read completely; fine details should be checked before being quoted. The 2026 "no-resource" paper was seen only as an abstract [@giagnorio2026].
- **No direct evidence on stack languages.** No study of LLMs writing Forth, RPN or stack languages was found. The claim that the stack is a disadvantage is a hypothesis (inference from non-local constraints and scarce training data), and the compiler survey cited is related only by analogy [@zhang2026]. The pass@1 figures come from studies of R, Racket, Julia and Lua, not of stack languages.
- **Attribution of figures.** The pass@1 ranges (7% to 33.1%; 19.2% to 61.4%) were carried over from the source report, which attributed them to the cited group of papers collectively; the exact paper-to-figure mapping was not re-checked.
- **Links.** No URL was re-tested for reachability in this write-up; the only fetches made were arXiv abstract pages to confirm titles and authors.
- **Process.** A single search on a single day by one subagent, with a Spanish-to-English reformatting step; the staged structure is reconstructed.

## References

```bibtex
@misc{numbatRepo,
  title={Numbat: a statically typed programming language for scientific computations with first class support for physical dimensions and units},
  author={{sharkdp}},
  howpublished={GitHub repository},
  url={https://github.com/sharkdp/numbat},
  note={Accessed: 2026-10-03}
}

@misc{numbatIntro,
  title={Numbat: Introduction},
  howpublished={Numbat website},
  url={https://numbat.dev/articles/intro.html},
  note={Accessed: 2026-10-03}
}

@misc{numbatFunctions,
  title={Numbat documentation: Function definitions},
  howpublished={Numbat website},
  url={https://numbat.dev/doc/function-definitions.html},
  note={Accessed: 2026-10-03}
}

@misc{fend,
  title={fend: Arbitrary-precision unit-aware calculator},
  author={{printfn}},
  howpublished={GitHub repository},
  url={https://github.com/printfn/fend},
  note={Accessed: 2026-10-03}
}

@misc{qalcMode,
  title={Qalculate! manual: Mode},
  howpublished={Qalculate! website},
  url={https://qalculate.github.io/manual/qalculate-mode.html},
  note={Accessed: 2026-10-03}
}

@misc{qalcManual,
  title={Qalculate! manual: qalc (command-line interface)},
  howpublished={Qalculate! website},
  url={https://qalculate.github.io/manual/qalc.html},
  note={Accessed: 2026-10-03}
}

@misc{frinkPF,
  title={Frink, the ultimate physics calculator and units converter},
  howpublished={Physics Forums thread},
  url={https://www.physicsforums.com/threads/frink-the-ultimate-physics-calculator-and-units-converter.514182/},
  note={Accessed: 2026-10-03. Weak secondary source}
}

@misc{rakuRat,
  title={Raku documentation: class Rat},
  howpublished={docs.raku.org},
  url={https://docs.raku.org/type/Rat},
  note={Accessed: 2026-10-03}
}

@misc{rakuNumerics,
  title={Raku documentation: Numerics},
  howpublished={docs.raku.org},
  url={https://docs.raku.org/language/numerics.html},
  note={Accessed: 2026-10-03}
}

@misc{shitovFatRat,
  title={FatRat vs Rat in Perl 6},
  author={Shitov, Andrew},
  year={2018},
  howpublished={Blog post},
  url={https://andrewshitov.com/2018/02/13/55-fatrat-vs-rat-in-perl-6/},
  note={Accessed: 2026-10-03}
}

@misc{julia,
  title={Julia documentation: Complex and Rational Numbers},
  howpublished={docs.julialang.org},
  url={https://docs.julialang.org/en/v1/manual/complex-and-rational-numbers/},
  note={Accessed: 2026-10-03}
}

@misc{wolframN,
  title={Wolfram Language documentation: N},
  howpublished={reference.wolfram.com},
  url={https://reference.wolfram.com/language/ref/N.html},
  note={Accessed: 2026-10-03}
}

@misc{hn14625795,
  title={Hacker News discussion item 14625795 (Insect)},
  howpublished={news.ycombinator.com},
  url={https://news.ycombinator.com/item?id=14625795},
  note={Accessed: 2026-10-03}
}

@misc{starlarkSpec,
  title={Starlark Language Specification},
  howpublished={GitHub, bazelbuild/starlark},
  url={https://github.com/bazelbuild/starlark/blob/master/spec.md},
  note={Accessed: 2026-10-03}
}

@misc{bazelLang,
  title={Bazel: The Starlark language},
  howpublished={bazel.build},
  url={https://bazel.build/rules/language},
  note={Accessed: 2026-10-03}
}

@misc{starlark97,
  title={Starlark issue 97: recursion},
  howpublished={GitHub issue, bazelbuild/starlark},
  url={https://github.com/bazelbuild/starlark/issues/97},
  note={Accessed: 2026-10-03}
}

@misc{celSpec,
  title={Common Expression Language specification},
  author={{Google}},
  howpublished={GitHub, google/cel-spec},
  url={https://github.com/google/cel-spec},
  note={Accessed: 2026-10-03}
}

@misc{k8sCel,
  title={Kubernetes CRD validation using CEL},
  howpublished={Google Open Source Blog},
  year={2023},
  url={https://opensource.googleblog.com/2023/11/kubernetes-crd-validation-using-cel.html},
  note={Accessed: 2026-10-03}
}

@misc{dhallSafety,
  title={Dhall documentation: Safety guarantees},
  howpublished={docs.dhall-lang.org},
  url={https://docs.dhall-lang.org/discussions/Safety-guarantees.html},
  note={Accessed: 2026-10-03}
}

@misc{dhallBlog,
  title={Dhall: a non-Turing-complete configuration language},
  howpublished={Haskell for all (blog)},
  year={2016},
  url={https://haskellforall.com/2016/12/dhall-non-turing-complete-configuration},
  note={Accessed: 2026-10-03}
}

@misc{wasmtimeInterrupt,
  title={Wasmtime documentation: Interrupting Wasm execution},
  howpublished={docs.wasmtime.dev},
  url={https://docs.wasmtime.dev/examples-interrupting-wasm.html},
  note={Accessed: 2026-10-03}
}

@misc{wasmtimeConfig,
  title={Wasmtime API: struct Config},
  howpublished={docs.wasmtime.dev},
  url={https://docs.wasmtime.dev/api/wasmtime/struct.Config.html},
  note={Accessed: 2026-10-03}
}

@misc{anthropicTools,
  title={Writing tools for agents},
  author={{Anthropic}},
  howpublished={Anthropic Engineering blog},
  url={https://www.anthropic.com/engineering/writing-tools-for-agents},
  note={Accessed: 2026-10-03}
}

@misc{devtoCli,
  title={Writing CLI tools that AI agents actually want to use},
  author={Uenyioha},
  howpublished={DEV Community blog post},
  url={https://dev.to/uenyioha/writing-cli-tools-that-ai-agents-actually-want-to-use-39no},
  note={Accessed: 2026-10-03. Blog, not peer reviewed}
}

@misc{arcjet,
  title={Designing a CLI for AI agents},
  howpublished={Arcjet blog},
  url={https://blog.arcjet.com/designing-a-cli-for-ai-agents/},
  note={Accessed: 2026-10-03. Blog, not peer reviewed}
}

@misc{kellyErrors,
  title={Designing error messages for LLMs},
  author={Kelly, Martha},
  howpublished={Blog post},
  url={https://www.marthakelly.com/blog/designing-error-messages-for-llms},
  note={Accessed: 2026-10-03. Blog, not peer reviewed}
}

@misc{clispec,
  title={clispec},
  howpublished={clispec.dev},
  url={https://clispec.dev/},
  note={Accessed: 2026-10-03}
}

@article{giagnorio2025,
  title={Enhancing Code Generation for Low-Resource Languages: No Silver Bullet},
  author={Giagnorio, Alessandro and Martin-Lopez, Alberto and Bavota, Gabriele},
  year={2025},
  journal={arXiv preprint},
  eprint={2501.19085},
  archivePrefix={arXiv},
  url={https://arxiv.org/abs/2501.19085},
  note={Accessed: 2026-10-03}
}

@article{cassano2023,
  title={Knowledge Transfer from High-Resource to Low-Resource Programming Languages for Code LLMs},
  author={Cassano, Federico and Gouwar, John and Lucchetti, Francesca and Schlesinger, Claire and Freeman, Anders and Anderson, Carolyn Jane and Feldman, Molly Q and Greenberg, Michael and Jangda, Abhinav and Guha, Arjun},
  year={2023},
  journal={arXiv preprint},
  eprint={2308.09895},
  archivePrefix={arXiv},
  url={https://arxiv.org/abs/2308.09895},
  note={Accessed: 2026-10-03}
}

@article{joel2024,
  title={A Survey on LLM-based Code Generation for Low-Resource and Domain-Specific Programming Languages},
  author={Joel, Sathvik and Wu, Jie JW and Fard, Fatemeh H.},
  year={2024},
  journal={arXiv preprint (accepted to ACM Transactions on Software Engineering and Methodology)},
  eprint={2410.03981},
  archivePrefix={arXiv},
  url={https://arxiv.org/abs/2410.03981},
  note={Accessed: 2026-10-03}
}

@article{giagnorio2026,
  title={No Resource, No Benchmarks, No Problem? Evaluating and Improving LLMs for Code Generation in No-Resource Languages},
  author={Giagnorio, Alessandro and Martin-Lopez, Alberto and Bavota, Gabriele},
  year={2026},
  journal={arXiv preprint (accepted to IEEE Transactions on Software Engineering)},
  eprint={2606.16827},
  archivePrefix={arXiv},
  url={https://arxiv.org/html/2606.16827v1},
  note={Accessed: 2026-10-03. Only the abstract was read}
}

@article{zhang2026,
  title={The New Compiler Stack: A Survey on the Synergy of LLMs and Compilers},
  author={Zhang, Shuoming and Zhao, Jiacheng and Yu, Qiuchu and Xia, Chunwei and Wang, Zheng and Feng, Xiaobing and Cui, Huimin},
  year={2026},
  journal={arXiv preprint},
  eprint={2601.02045},
  archivePrefix={arXiv},
  url={https://arxiv.org/pdf/2601.02045},
  note={Accessed: 2026-10-03}
}
```
