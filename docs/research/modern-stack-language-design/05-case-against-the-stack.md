# The Case Against the Stack: A Devil's-Advocate Brief and Two Alternative Designs for cx

## Abstract

Reports 00 to 04 in this folder ask how cx's RPN should grow into a modern stack language. This brief asks the prior question: should the stack be the identity of the language at all? It is written as a devil's advocate, at the author's request, and argues the case against as hard as the evidence allows. It also states the strongest case for the stack and says where that case holds.

The brief judges the stack against the author's own goals:
- agents write the code;
- humans review it;
- host programs embed it with named parameters;
- it has first-class tooling;
- it is adopted the way SQL is;
- its specification reads like a haiku.

On each goal, the evidence either points away from a stack surface or does not support one. The sharpest single finding is internal: the recommended hybrid (report 00) already contains a complete infix expression grammar, through its infix bridge. An expression language is therefore a strict subset of the hybrid's specification, not a rival to it.

The brief proposes two alternatives and writes the same three programs in each and in the current stack proposal:
- **Design A**, an expression language with `let`, `fn`, `|>` pipelines and declared parameters;
- **Design B**, a declarative formula sheet: named single-assignment equations with `input` and `output`, acyclic and total by construction, closest to the spirit of SQL and spreadsheets.

The recommendation is to keep the stack as the engine's machine model, its intermediate representation, and an interactive calculator mode. The language of record would become Design B, built on Design A's expression core. Before syntax is frozen, a benchmark round (r4) should settle the question with a pre-registered decision rule.

## Research Question

Judged by the author's stated goals, is a stack (postfix, concatenative) surface the right identity for the cx language? If not, which alternative designs serve those goals better, and what experiment would settle the question?

## Scope and Constraints

- **Stance.** This document argues one side on purpose. It is not a neutral survey. The counter-case is stated in its own section, "The strongest case for the stack", and the recommendation is meant to survive it.
- **The author's goals, taken as given:**
  - a formal open language for calculation, with a spec, several engines, a linter, a language server and a VS Code extension;
  - the SQLite model of embedding: host programs in Dart, TypeScript, Python or Rust pass program text, bind parameters and execute;
  - "compile" means validate, package and deploy, not native code;
  - the primary user is a software engineer who designs and delegates implementation to AI agents, then reviews what they write;
  - a spec that is "clear as a haiku, precise as a kata", in code that "reveals its purpose".
- **Principles held fixed** (report 00):
  - exact by default;
  - nothing degrades silently;
  - deterministic and hermetic;
  - bounded execution;
  - one obvious way;
  - user words indistinguishable from primitives.
- **Out of scope:** the name of the language, units beyond a sketch, and implementation plans past the experiment.
- **Constraint:** no source studies LLMs writing stack languages directly. Report 03 found none, and this search found none. Every claim about agents and the stack is therefore an inference from neighbouring evidence, and is marked as such.

## Method (Staged Protocol)

1. **Repo reading (2026-10-03).** Reports 00 to 04 and `docs/mission.md` were read, along with `benchmark/README.md`, `benchmark/tasks-hard.txt` and the local round-r3 logs in `benchmark/runs/`. These logs are ignored by git, so they exist only on the maintainer's machine. The infix evaluator in `code/core/lib/src/evaluation/calculatrix.dart` was also read.
2. **Web search and fetch (same day).** Sources were sought on:
   - LLM performance on low-resource and out-of-distribution languages;
   - state tracking in LLMs;
   - the readability of stack code;
   - identifier names and comprehension;
   - the fate of RPL, Factor, Forth and Uiua;
   - how SQL, CEL, Excel formulas, Wasm text and Numbat handle names and parameters.

   Claims were checked against the fetched page, abstract or PDF wherever possible. A claim seen only in a search snippet is marked so.
3. **Design.** The two alternatives were written against the six principles. The three example programs were then written in all three designs.
4. **Confidence.** Each finding is rated high, medium or low, according to how directly the evidence bears on cx.

## Findings by Stage

### Stage 1 - Problem Framing

**Identity versus mechanism.** The question splits into two. The first is whether cx should *execute* on a stack. That is a question about mechanism, and nothing here argues against it. The second is whether the *language people and agents write and read* should be postfix and concatenative. That is a question about identity, and this brief argues against it.

**Shift in the primary user.** The author's goals moved the primary user from the HP-calculator user typing at a keypad to two readers:
- an agent that writes whole programs from a natural-language request;
- a human who reviews those programs without having written them.

Every criterion below follows from that shift.

**Criteria, in the order of the author's goals:**
1. Agent writing accuracy.
2. Human review ("code reveals its purpose").
3. Embedding with named parameters.
4. Tooling: hover, types, error localization.
5. Adoption.
6. Spec size and "one obvious way".

### Stage 2 - Source Discovery

| Group | Sources |
|---|---|
| Repo | reports 00, 02, 03 [@cx00synthesis; @cx02concatenative; @cx03numeric]; mission [@cxmission]; benchmark README and r3 logs [@cxbenchreadme; @cxr3logs]; infix evaluator [@cxinfix] |
| LLMs and languages | MultiPL-T [@cassano2024]; EsoLang-Bench [@sharma2026esolang]; entity tracking [@kim2023entity] |
| Readability | identifier-name experiment [@hofmeister2019]; Factor DLS paper [@pestov2010factor]; Kreinin on Forth [@kreinin2010]; Moore's "1x Forth" [@moore1999]; Schwartz on Uiua and BQN [@schwartz2024] |
| Successful calculation and embedded languages | Excel LET [@msLet] and LAMBDA [@gordon2021lambda]; CEL [@celspec]; SQLite parameter binding [@sqliteBind]; Wasm folded instructions [@wasmFolded]; Numbat [@numbat] |
| Stack-language trajectories | HP Prime and HP PPL [@hpprime]; Kitten (via report 02) [@cx02concatenative] |

### Stage 3 - Source Triage

**Strong:**
- peer-reviewed or archival papers [@cassano2024; @kim2023entity; @hofmeister2019; @pestov2010factor];
- official documentation [@msLet; @celspec; @sqliteBind; @wasmFolded; @numbat];
- the repo's own benchmark logs, which are direct but small.

**Medium:**
- EsoLang-Bench [@sharma2026esolang], a 2026 preprint seen as an abstract;
- the Microsoft Research blog [@gordon2021lambda];
- Wikipedia for HP Prime [@hpprime].

**Weak, used as testimony only:**
- Kreinin's and Schwartz's personal essays [@kreinin2010; @schwartz2024];
- Moore's talk transcript [@moore1999].

**Dropped:**
- a claim that Wikipedia calls Forth "write-only", because the fetched article does not say so;
- a claim about the default entry mode of the HP 49/50, because the fetched article does not state it.

### Stage 4 - Evidence Extraction

#### 4.1 Agent writing accuracy

| Finding | Evidence | Confidence |
|---|---|---|
| Code LLMs "struggle with low-resource languages", and performance tracks the language's share of training data. | MultiPL-T, OOPSLA 2024 [@cassano2024] | high |
| On languages outside the training distribution, the gap is drastic. The same 80 problems reach 100% in Python and JavaScript on top frontier models and 0–11% in esoteric languages. Few-shot prompting and self-reflection do not close the gap. | EsoLang-Bench [@sharma2026esolang]. Caveat: its languages, one of them stack-based (Befunge-98), are hostile by design, so this is an upper bound on the effect. | medium as evidence on direction, low as an estimate of size |
| Tracking how state changes through a sequence of operations is a distinct capability. In 2023-era models it degraded on longer operation sequences. | Kim and Schuster, ACL 2023 [@kim2023entity] | low for 2026 frontier models; the mechanism is relevant |
| Stack code turns every intermediate value into implicit, position-addressed state that the writer must track across tokens. Names make that state explicit in the text. | Inference from the two rows above and from report 03 [@cx03numeric] | medium (inference) |
| **In cx's own benchmark, a stack program produced a silent wrong value.** In round r3, task 7 (A⁻³ by multiplication), Codex gpt-6-luna ran `[[1 2] [0 1]] inverse dup * dup *`. That computes A⁻⁴, and cx returned `[[1 -8] [0 1]]` with exit 0. The agent's next attempt, `inverse swap drop dup 2 pick * *`, failed with `stack-underflow` at `swap`. Its third, `inverse dup 2 pick * *`, was correct. | local r3 log `r3-hard-cx/codex-gpt-6-luna.txt` [@cxr3logs] | high that it happened; low as a rate (1 run of 18) |
| Other stack frictions in r3 `cx` mode: | | high that they happened; low as a rate |
| - argument order for `vector` caused a `stack-underflow` (agy Claude Sonnet 4.6); | r3 logs [@cxr3logs] | |
| - a negative exponent, `-3`, needed the `--` separator (agy Gemini 3.8 Flash); | r3 logs [@cxr3logs] | |
| - Claude Haiku reported "RPN/infix syntax confusion". | r3 logs [@cxr3logs] | |
| **Counter-evidence.** Agents using cx in r3 were highly accurate: 197 of 198 answers correct in `cx` mode. The only wrong one came from a run that never called cx. | benchmark README [@cxbenchreadme] | high, but every r3 task is one matrix literal plus one or two words, which is the stack's best case |

#### 4.2 Human review and readability

| Finding | Evidence | Confidence |
|---|---|---|
| Factor's designers write: "Numerical formulas often exhibit non-trivial data flow and benefit in readability and ease of implementation from using locals." | Pestov, Ehrenberg and Groff, DLS 2010 [@pestov2010factor] | high, and it is the stack community's own verdict on cx's exact domain |
| Forth's creator gives the discipline under which stack code stays readable: "A Forth word should not have more than one or two arguments", and the stack "should never be more than three or four deep". | Moore, "1x Forth" [@moore1999] | high as a statement of the rule |
| The quadratic formula needs three inputs, and so does a price with discount and tax. Business formulas routinely need 4 to 8. By Moore's own rule, cx's core workload sits outside the zone where stack code is comfortable. | inference from the row above | medium |
| Word identifiers let 72 professional developers find defects 19% faster than single letters or abbreviations. Stack code has no names for intermediate values at all. | Hofmeister, Siegmund and Holt, EMSE 2019 [@hofmeister2019] | medium: the study compares naming styles, not stack against named code |
| Practitioners who tried stack-only code at scale report that they left because of stack juggling. Kreinin: "The abundance of DUP, SWAP, -ROT and -ROT3 in my code shows that making it flow wasn't very easy", and his team moved to C. Schwartz, on Uiua: "the lack of local variables just compounds complexity", and he moved to BQN. | [@kreinin2010; @schwartz2024] | low (testimony) |
| When stack machines need human-readable text, they add expression syntax. The Wasm text format lets instructions be written "in folded form, to group them visually", that is, as nested expressions. | Wasm spec [@wasmFolded] | high |

#### 4.3 Embedding with named parameters

| Finding | Evidence | Confidence |
|---|---|---|
| SQLite, the model the author cites, binds named parameters (`:VVV`, `@VVV`, `$VVV`) as well as positional `?`. Hosts look up names with `sqlite3_bind_parameter_index()`. | SQLite C API [@sqliteBind] | high |
| CEL, an embeddable, non-Turing-complete expression language with several engines (Go, C++, Java), uses C-style infix syntax over named variables declared by the host. | cel-spec [@celspec] | high |
| A stack word's interface is positional by construction. In Forth tradition the names in `( a b -- c )` are a comment, and report 00 proposes checking only the count. Named binding from a host therefore needs the locals layer (`->`), which means the non-stack part of the hybrid. | [@cx00synthesis; @cx02concatenative] | high |
| Without named binding, hosts build program text by interpolation, for example `f"{price} {discount} price-total"`. That is the anti-pattern parameterized SQL was invented to remove. In a hermetic language it cannot leak data, but it can change the result silently: a value such as `"1 drop 0"` becomes code. | inference | medium |
| Positional stacks have no natural default parameters, such as `discount = 0`. | inference | medium |

#### 4.4 Tooling

| Finding | Evidence | Confidence |
|---|---|---|
| In a named language, hover on a name shows a value and a type. In a stack language the program state at a cursor is a stack, and showing it requires stack-effect inference over quotations and branches. Report 00 itself defers branch-by-branch depth checking to a lint in 0.21. | [@cx00synthesis] | medium |
| A stack error is reported where the stack ran dry, not where the mistake was. In r3, gpt-6-luna's underflow was reported at `swap` (position 23), but the error was in the plan, and the earlier wrong program raised no error at all. | [@cxr3logs] | medium |
| cx's infix front end already tokenizes with positions and compiles to positioned RPN tokens by shunting-yard (`compileInfix`). The engine therefore already has an expression surface that lowers to the stack machine. | `calculatrix.dart` [@cxinfix] | high |

#### 4.5 Adoption

| Finding | Evidence | Confidence |
|---|---|---|
| HP's current graphing calculator, the Prime, dropped RPL. It runs a new OS that is "not compatible with any User RPL or System RPL", and it is programmed in HP PPL, "a new, Pascal-like programming language". RPN survives only as an entry mode. | Wikipedia, HP Prime [@hpprime] | high for the facts; HP's reasons are not documented in the source |
| Kitten, the typed concatenative language designed for usability, added infix operators and locals, and has had no active development since about 2018. | report 02 [@cx02concatenative] | medium |
| The world's most widely used calculation language, Excel formulas ("written by an order of magnitude more users than all the C, C++, C#, Java, and Python programmers in the world combined"), grew toward names. It added `LET` in 2020 and `LAMBDA` in 2021. Microsoft justifies `LET` by readability: names "give meaningful context to yourself and consumers of your formula". | [@gordon2021lambda; @msLet] | high for the facts; the usage claim is Microsoft's own |
| The newest calculation language in report 03's survey, Numbat, is infix with names, static types and units. | [@numbat] | high |
| Stack languages succeed mostly as machine-generated targets: PostScript, JVM and CPython bytecode, and Wasm. Hand-written stack languages remain niche. | general knowledge plus [@wasmFolded]; no source measures niche status | low to medium |

#### 4.6 Spec size and "one obvious way"

| Finding | Evidence | Confidence |
|---|---|---|
| The recommended hybrid is built from: RPN tokens, `{ }` quotations, `: name ( effect ) ... ;` definitions, a stack-effect sub-language, `-> a b c` locals, and the infix bridge `'...'`. The infix bridge alone needs a full precedence grammar with function calls. **The hybrid's grammar is therefore a superset of an expression language's grammar.** | [@cx00synthesis] | high |
| The hybrid gives three ways to write the same formula: pure stack, locals with a quotation, and locals with infix. Report 00 proposes benchmarking "three styles", which concedes that there is no one obvious way. | [@cx00synthesis] | high |

### Stage 5 - Synthesis and Limits

**Summary by goal:**
- **Agent writing.** The direction of the evidence is clear, and its size for cx is unknown. Familiar syntax helps LLMs, and position-addressed state is what they track worst. cx's single data point shows a stack program that was silently wrong.
- **Human review.** Even Factor's authors concede that formulas need locals.
- **Embedding.** Named parameters require the hybrid's non-stack layer.
- **Tooling.** Stack state at a cursor is harder to show, and errors surface far from their cause.
- **Adoption.** HP, Excel, Numbat and CEL all point to named infix.
- **Spec size.** The hybrid is the largest of the candidates, because it contains the expression language.

**Limits.** The agent evidence is indirect. r3 measured one-step tasks, where the stack does well. The testimony is anecdotal, and the author of this brief was asked to take a side.

## Discussion

### The strongest case for the stack, and why it is not decisive

1. **Backward compatibility and identity.** Every valid RPN program stays valid, and the HP lineage gives cx a recognizable character.

   *Not decisive.* Compatibility is kept by making RPN a dialect that compiles to the same core, the way `eval rpn` and `eval infix` already share one engine [@cxinfix]. As for identity, `docs/mission.md` says cx competes on **trust** and **usability** [@cxmission]. Neither is a property of postfix notation. The identity worth defending is "never a silent wrong result", and the r3 log shows the stack producing one [@cxr3logs].

2. **A trivial parser makes many engines cheap.** This matters for the multi-engine, SQLite-like vision.

   *Partly decisive, but small.* A Pratt or precedence-climbing parser is a few hundred lines in any language. cx already has one, and an agent ports one routinely. The hard part of engines that agree is the numeric semantics and the conformance suite (report 04), not the parser. The stack does give one real advantage here: the evaluation model can be specified exactly as stack steps. The alternatives keep that advantage by specifying their semantics as lowering to the same stack machine.

3. **Concatenation is composition.** Programs refactor by cut and paste, and unary chains read left to right: `M inv det`.

   *Real, and kept.* Design A's pipeline `M |> inv |> det` preserves exactly this left-to-right data flow. The stack's advantage disappears where data flow stops being a chain, that is, as soon as a value is used twice or three inputs combine. That is formulas, cx's domain [@pestov2010factor; @moore1999].

4. **Agents already succeed with cx's RPN.** In r3 `cx` mode, 197 of 198 answers were correct [@cxbenchreadme].

   *Valid for one-liners.* Every r3 task is a literal followed by one word. The only multi-step stack task (task 7) produced the silent wrong value. r3 does not test programs, which is exactly what the author now wants agents to write.

5. **Factor shows locals are rarely needed.** Only 326 of about 37,000 Factor definitions use named parameters [@pestov2010factor].

   *The strongest pro-stack datum, but from the wrong domain.* That count covers a compiler, an IDE and libraries, written by stack experts. The same paper says numerical formulas are the exception.

6. **User words are indistinguishable from primitives.** This is natural in a stack language.

   *Equal, not better.* In Designs A and B, `fact(n)` and `sqrt(n)` have the same call syntax.

7. **An interactive calculator wants a visible stack.** The stack is a superb user interface for a keypad.

   *Decisive, for that interface.* Keep it there: in the app and in `cx` one-liners, as a mode, not as the language of record.

**Where the stack wins outright:** as the machine model, as the intermediate representation that gives a deterministic step count for the fuel budget, and as an interactive input mode. None of these requires that programs be written in postfix.

### The three programs in the current stack proposal (report 00 syntax, not implemented)

```
# 1. factorial
: fact ( n -- n! )  dup 1 <= { drop 1 } { dup 1 - fact * } ifelse ;
20 fact

# 2. quadratic roots
: roots ( a b c -- x1 x2 )
  -> a b c '(-b + sqrt(b^2 - 4*a*c)) / (2*a)'  '(-b - sqrt(b^2 - 4*a*c)) / (2*a)' ;
1 -3 2 roots

# 3. price with discount and tax
: price-total ( price discount rate -- total )
  -> price discount rate 'round(price * (1 - discount) * (1 + rate), 2)' ;
# pure-stack equivalent: : price-total ( p d r -- t ) 1 + rot rot 1 swap - * * ;
```

Notes on these programs:
- **Program 2** has to leave the stack, through the infix bridge, to stay readable.
- **Program 3** can be embedded from a host only positionally, and it has no default for `discount`:

  ```python
  cx.run("price-total", stack=["19.99", "1/10", "21/100"])   # order must match the effect
  cx.run(f"{price} {discount} {rate} price-total")            # what hosts will actually do
  ```

- **The pure-stack line** is correct, but checking it means simulating four stack states.

### Design A - Expression language with declared parameters

**Thesis.** A program is one expression, preceded by declarations:
- `param` for host inputs, with optional defaults;
- `fn` for functions;
- `let` to name intermediate values.

Control flow is an expression (`if … then … else …`), and `|>` pipes a value into a function, keeping the left-to-right reading that RPN users value. The grammar is the one cx already implements in `eval infix`, plus five productions. Semantics are defined by lowering to the existing stack machine, so the RPN engine, its rollback, its digit budget and its step count stay the reference model. This is CEL's shape [@celspec], with SQLite's binding model [@sqliteBind] and Excel's `LET` and `LAMBDA` [@msLet; @gordon2021lambda].

```
# 1. factorial
fn fact(n) = if n <= 1 then 1 else n * fact(n - 1)
fact(20)

# 2. quadratic roots
fn roots(a, b, c) =
  let d = b^2 - 4*a*c;
  [(-b + sqrt(d)) / (2*a), (-b - sqrt(d)) / (2*a)]
roots(1, -3, 2)

# 3. price with discount and tax (file pricing.cx)
param price
param discount = 0
param tax_rate = 21%
let net = price * (1 - discount);
round(net * (1 + tax_rate), 2)
```

The host prepares the program once and binds by name:

```python
pricing = cx.prepare(open("pricing.cx").read())   # parse, resolve names, check arity: once
total = pricing.run(price="19.99", discount="10%")  # unknown or missing name -> stable error id
```

```typescript
const total = pricing.run({ price: "19.99", discount: "10%" });
```

Values cross the boundary as decimal strings or exact rationals. Binding a binary float is an error unless the host marks it approximate. This holds in every design.

**Grammar sketch (about 14 productions).** The precedence part already exists in the engine.

```
program  = { decl } expr ;
decl     = "param" NAME [ "=" expr ] NL
         | "fn" NAME "(" [ NAME { "," NAME } ] ")" "=" expr NL ;
expr     = "let" NAME "=" expr ";" expr
         | "if" expr "then" expr "else" expr
         | pipe ;
pipe     = or { "|>" postfix } ;
or       = and { "or" and } ;          and = cmp { "and" cmp } ;
cmp      = add [ ("<"|"<="|"=="|"!="|">="|">") add ] ;
add      = mul { ("+"|"-") mul } ;     mul = unary { ("*"|"/") unary } ;
unary    = [ "-" | "not" ] pow ;       pow = postfix [ "^" unary ] ;
postfix  = primary { "(" [ args ] ")" | "%" } ;
primary  = NUMBER | NAME | "(" expr ")" | matrix ;
matrix   = "[" [ row { ";" row } ] "]" ;  row = expr { "," expr } ;
```

**How Design A keeps the principles:**

| Principle | How |
|---|---|
| Exact by default | Same numeric tower and same core. `round` is an explicit, named operation. |
| Nothing degrades silently | Approximate values are marked, and limits are errors. Unbound or unknown parameters are errors, which a positional stack cannot detect. |
| Deterministic and hermetic | No I/O, clock or randomness; unchanged from today. |
| Bounded execution | Recursion runs under the step budget, counted as stack-machine steps after lowering. |
| One obvious way | One syntax for formulas. Pipelines are only sugar for unary calls, and the formatter canonicalizes them. |
| User words equal primitives | `fact(n)` and `sqrt(n)` have the same form. |

**What is lost:**
- Postfix as the primary syntax, and the HP feel.
- Today's matrix literal `[[1 2] [3 4]]` becomes `[1, 2; 3, 4]` in expression syntax, because spaces are ambiguous with binary minus. Today's form stays in RPN mode.
- Point-free tricks.
- About five productions more than pure RPN, though fewer than the hybrid.

### Design B - Formula sheet (declarative, single assignment, total)

**Thesis.** A program is a set of named equations, not a sequence of steps. This is SQL's idea (state *what*, let the engine decide *how*) applied to calculation, and the spreadsheet's idea without the grid:
- `input` lines declare host parameters;
- plain lines define named values or functions;
- `output` lines are what the host may ask for;
- order does not matter;
- every name is assigned once;
- the dependency graph must be acyclic, which is checked statically.

There is no general recursion. Iteration goes through bounded built-ins over finite collections (`sum`, `product`, `fold`, `iterate(f, x0, n)`). Termination is therefore a property of the language, as in Starlark or Dhall (report 03), not only of a budget. The expression grammar is Design A's.

```
# 1. factorial
input n where n >= 0
output fact = product(1..n)

# 2. quadratic roots
input a, b, c
disc = b^2 - 4*a*c
output x1 = (-b + sqrt(disc)) / (2*a)
output x2 = (-b - sqrt(disc)) / (2*a)

# 3. price with discount and tax (file pricing.cx)
input price
input discount = 0
input tax_rate = 21%
net = round(price * (1 - discount), 2)
tax = round(net * tax_rate, 2)
output total = net + tax
```

The host works with the sheet the way it works with a prepared statement:

```python
sheet = cx.prepare(open("pricing.cx").read())
r = sheet.evaluate(inputs={"price": "19.99", "discount": "10%"}, outputs=["total", "tax"])
# r.total == 2177/100, r.tax == 189/50
r.explain("total")   # total = net + tax = 17.99 + 3.78 = 21.77  (a derivation, by name)
```

**Grammar sketch: Design A's expression grammar, minus `param`, `fn` and `let`, plus three line forms.**

```
sheet = { line NL } ;
line  = "input" NAME { "," NAME } [ "where" expr ] [ "=" expr ]
      | [ "output" ] NAME [ "(" NAME { "," NAME } ")" ] "=" expr ;
```

User functions are equations with parameters, for example `square(x) = x * x`.

**How Design B keeps the principles:**

| Principle | How |
|---|---|
| Exact by default | As in Design A. |
| Nothing degrades silently | Every intermediate is named, so `explain` can show where approximation entered. `where` guards turn precondition failures into errors with stable ids. |
| Deterministic and hermetic | As today. |
| Bounded execution | Acyclicity, plus iteration only over finite ranges. Termination holds by construction, and the step and digit budgets remain as defence in depth. |
| One obvious way | Each value has exactly one defining line. |
| User words equal primitives | `square(x)` and `sqrt(x)` look the same. |

**What Design B does better than A for the author's goals:**
- **Review.** Each line is a claim a reviewer can check against the requirement it implements: "tax is the net times the rate, rounded to cents".
- **Tooling.** Hover shows any name's definition and, in a live session, its value. The language server gets go-to-definition, find-dependents and per-equation errors almost for free.
- **Embedding.** It is the closest analogue of a SQL query: inputs bound by name, outputs selected by name.
- **Testing and deployment.** "Compile" (validate, package, deploy) means checking that the dependency graph is acyclic, that names resolve and that guards are well typed. That is a dacpac-like artifact.

**What is lost:**
- General recursion and stateful algorithms, such as Euclid's gcd loop or Newton's method until convergence, must use built-ins (`iterate`, `fold`). Otherwise an opt-in `recursive fn` runs under fuel, and that weakens totality.
- Statement order cannot express effects, but cx has none.
- It is the furthest from today's cx.

### Variants considered

- **A typed layer with units (Numbat-like) [@numbat].** This is not a third surface. It is an orthogonal addition to A or B: `input price : Money`, `input v : Length / Time`. It is worth having after the experiment. It adds a type grammar, and it catches a class of errors that no syntax catches.
- **An array language (APL, BQN, Uiua).** Rejected as the surface. Glyph vocabularies are the opposite of in-context learnability for agents, and tacit style is where the readability complaints concentrate [@schwartz2024]. Its idea of whole-matrix operations without loops is already cx's, through words such as `det` and `inv`.

### Side-by-side comparison

| Criterion | Stack hybrid (report 00) | A: expression | B: formula sheet |
|---|---|---|---|
| Grammars in the spec | postfix, quotations, effects, locals, **plus infix** | infix only | infix plus three line forms |
| Ways to write a formula | 3 | 1 | 1 |
| Named host parameters | only through `->` | `param` | `input` and `output` |
| Defaults for parameters | no | yes | yes |
| Termination | step budget | step budget | by construction, plus budget |
| Error at the cause | underflow at the consumer | name or arity error at the use | per equation, static |
| Hover | a stack state | name, value, type | name, definition, value |
| Training-data neighbours | Forth, PostScript (rare) | Python, Excel, CEL, Julia (abundant) | Excel, SQL, Numbat |
| Today's RPN programs | valid | valid in RPN mode | valid in RPN mode |

## Conclusion

1. **The stack is the machine, not the language.** Specify cx's semantics as lowering to the existing stack machine, because that gives an exact, portable meaning, rollback and deterministic step counting. Keep RPN as an input mode for `cx` one-liners and the app keypad. Stop treating postfix as the identity of the language.
2. **Make Design B the language of record, built on Design A's expression core.** B is the design that answers "for anything computational, use this", in the way SQL answers it for data: named inputs, named outputs, declarative equations, guaranteed termination. A is its expression grammar, and that grammar already exists in `eval infix` [@cxinfix].
3. **Do not build `{ }` quotations, `: ;` definitions or `->` locals yet.** Phases 0.17 and 0.18 of report 00 (front end, positions, trace, JSON errors, limits, conformance format) are neutral to the notation and should proceed. Phases 0.20 to 0.22 should wait for the experiment below.
4. **Settle the question with round r4 of the existing benchmark** (`benchmark/run-trial.ps1`, its modes and its friction ledger [@cxbenchreadme]).
   - **Tasks.** A new set, `tasks-programs.txt`, of about 12 tasks that need *programs*, not one-liners:
     - formulas with reused subexpressions and three or more inputs;
     - a conditional;
     - a recursion or bounded iteration;
     - a host-embedding task ("write `pricing.cx` so that this Python call works");
     - three review tasks, each showing a program with a planted bug and asking for it.
   - **Notations.** Three conditions: the stack hybrid, Design A and Design B. Each gets a one-page spec of equal token length in context, since no model has training data for any of them. Each runs on a thin reference front end that lowers to calculatrix_core. A and B share one parser, and the hybrid needs its own.
   - **Models.** The r3 roster of 18 configurations: 18 × 3 × 12 ≈ 650 graded task attempts.
   - **Metrics:**
     - first-attempt correctness;
     - **silent-wrong rate**, meaning exit 0 with a wrong value, the mission's first principle;
     - attempts to a correct result;
     - tokens;
     - bug-detection rate on the review tasks.
   - **Human arm.** A small one: 5 to 10 junior engineers predict the output of 6 programs per notation, timed.
   - **Pre-registered decision rule.** Keep the stack as the language of record only if the hybrid is within 5 percentage points of the best alternative on first-attempt correctness **and** has no higher silent-wrong rate **and** no lower review-detection rate. Otherwise adopt B on A.

**Confidence:**
- high that the hybrid's spec contains an expression language, and that named binding needs its non-stack layer;
- medium that a named surface improves agent accuracy and review for cx;
- low on the size of the effect, until r4 measures it.

## Limitations

- **Advocacy.** This brief argues one side by design. Its counter-case section is an honest attempt, not a neutral weighing.
- **Indirect agent evidence.** No study measures LLMs writing stack languages. MultiPL-T and EsoLang-Bench concern other languages, and EsoLang-Bench's languages are hostile by design. The entity-tracking result is from 2023 models.
- **Benchmark anecdotes.** The r3 stack failures are a few events in 18 runs, on tasks that favour the stack. They show that the failure mode exists, not how often it occurs. The logs are local, because `benchmark/runs/` is ignored by git.
- **Unprototyped designs.** Designs A and B are untested. Their grammar sizes are sketches, and details are open: matrix literal syntax, `round` semantics, `where` guards.
- **Testimony.** The sources by Kreinin, Schwartz and Moore are personal and were used only as testimony.
- **Adoption causes.** The reasons HP dropped RPL in the Prime are not documented in the source used. The claim that hand-written stack languages are niche is general knowledge, not a measurement.

## References

```bibtex
@misc{cx00synthesis,
  title={From RPN to a Modern Stack Language for cx: Synthesis and Recommendations},
  author={calculatrix project},
  year={2026},
  note={docs/research/modern-stack-language-design/00-synthesis-and-recommendations.md}
}

@misc{cx02concatenative,
  title={Stack and Concatenative Languages: State of the Art for the Design of cx},
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

@misc{cxmission,
  title={Mission},
  author={calculatrix project},
  year={2026},
  note={docs/mission.md}
}

@misc{cxbenchreadme,
  title={Benchmark (README, round r3 results)},
  author={calculatrix project},
  year={2026},
  note={benchmark/README.md}
}

@misc{cxr3logs,
  title={Round r3 run logs, cx mode},
  author={calculatrix project},
  year={2026},
  note={benchmark/runs/r3-hard-cx/*.txt (local, git-ignored); see codex-gpt-6-luna.txt, agy-claude-sonnet-4-6.txt, agy-gemini-3.8-flash-high.txt, claude-haiku.txt}
}

@misc{cxinfix,
  title={calculatrix core: infix tokenizer and shunting-yard compilation to positioned RPN},
  author={calculatrix project},
  year={2026},
  note={code/core/lib/src/evaluation/calculatrix.dart (compileInfix, evaluateInfix)}
}

@article{cassano2024,
  title={Knowledge Transfer from High-Resource to Low-Resource Programming Languages for Code LLMs},
  author={Cassano, Federico and Gouwar, John and Lucchetti, Francesca and Schlesinger, Claire and Freeman, Anders and Anderson, Carolyn Jane and Feldman, Molly Q and Greenberg, Michael and Jangda, Abhinav and Guha, Arjun},
  journal={Proceedings of the ACM on Programming Languages (OOPSLA)},
  year={2024},
  doi={10.1145/3689735},
  note={arXiv:2308.09895}
}

@misc{sharma2026esolang,
  title={EsoLang-Bench: Evaluating Genuine Reasoning in Large Language Models via Esoteric Programming Languages},
  author={Sharma, Aman and Chopra, Paras},
  year={2026},
  eprint={2603.09678},
  archivePrefix={arXiv},
  url={https://arxiv.org/abs/2603.09678}
}

@inproceedings{kim2023entity,
  title={Entity Tracking in Language Models},
  author={Kim, Najoung and Schuster, Sebastian},
  booktitle={Proceedings of the 61st Annual Meeting of the Association for Computational Linguistics (Volume 1: Long Papers)},
  pages={3835--3855},
  year={2023},
  url={https://aclanthology.org/2023.acl-long.213/}
}

@article{hofmeister2019,
  title={Shorter identifier names take longer to comprehend},
  author={Hofmeister, Johannes C. and Siegmund, Janet and Holt, Daniel V.},
  journal={Empirical Software Engineering},
  year={2019},
  doi={10.1007/s10664-018-9621-x},
  note={First presented at SANER 2017}
}

@inproceedings{pestov2010factor,
  title={Factor: A Dynamic Stack-based Programming Language},
  author={Pestov, Slava and Ehrenberg, Daniel and Groff, Joe},
  booktitle={Proceedings of the 6th Symposium on Dynamic Languages (DLS)},
  year={2010},
  url={https://factorcode.org/slava/dls.pdf}
}

@misc{kreinin2010,
  title={My history with Forth \& stack machines},
  author={Kreinin, Yossi},
  year={2010},
  url={https://yosefk.com/blog/my-history-with-forth-stack-machines.html}
}

@misc{moore1999,
  title={1x Forth},
  author={Moore, Charles H.},
  year={1999},
  url={https://www.ultratechnology.com/1xforth.htm}
}

@misc{schwartz2024,
  title={Hello BQN, goodbye APL and Uiua},
  author={Schwartz, Edward J.},
  year={2024},
  url={https://edmcman.github.io/blog/2024-12-20--hello-bqn-goodbye-apl-and-uiua/}
}

@misc{msLet,
  title={LET function},
  author={Microsoft},
  url={https://support.microsoft.com/en-us/office/let-function-34842dd8-b92b-4d3f-b325-b8b8f9908999}
}

@misc{gordon2021lambda,
  title={LAMBDA: The ultimate Excel worksheet function},
  author={Gordon, Andy and Peyton Jones, Simon},
  year={2021},
  howpublished={Microsoft Research Blog},
  url={https://www.microsoft.com/en-us/research/blog/lambda-the-ultimatae-excel-worksheet-function/}
}

@misc{celspec,
  title={Common Expression Language (CEL) specification},
  author={Google},
  url={https://github.com/google/cel-spec}
}

@misc{sqliteBind,
  title={Binding Values To Prepared Statements},
  author={SQLite},
  url={https://www.sqlite.org/c3ref/bind_blob.html}
}

@misc{wasmFolded,
  title={WebAssembly Core Specification: Text Format, Instructions (folded instructions)},
  author={WebAssembly Community Group},
  url={https://webassembly.github.io/spec/core/text/instructions.html}
}

@misc{hpprime,
  title={HP Prime},
  author={Wikipedia contributors},
  url={https://en.wikipedia.org/wiki/HP_Prime},
  note={Accessed 2026-10-03}
}

@misc{numbat,
  title={Numbat: a statically typed programming language for scientific computations with first class support for physical dimensions and units},
  author={Peter, David (sharkdp)},
  url={https://github.com/sharkdp/numbat}
}
```
