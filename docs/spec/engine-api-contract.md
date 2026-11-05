# Engine API contract

Status: **draft 0.2**, for language version 0.1.

Model: SQLite. One language with one specification, and one engine per
host language (Dart, TypeScript, Python, Rust...). The host passes
program text, binds named values, runs it and reads the results. Every
engine passes the same conformance suite; this contract is what that
suite tests at the API boundary.

What a program means is in `language.md`; what each mathematical word
computes is in `calculatrix_mathematics.md`. This contract defines only
how a host calls an engine. No implementation is normative.

Each clause has an id (`E1`, `E2`...) so tests and reviews can cite it.
An id is never reused; a clause that goes away leaves its number
unused.

## Changes

| Version | Date | Changes |
|---|---|---|
| 0.1 | 2026-10-05 | First draft. |
| 0.2 | 2026-11-04 | Aligned with language 0.1: one value type, values as text, `parameter`, sessions, explicit notation, limit defaults, snake_case ids, approximate values within a tolerance. `Program.call` removed. |

## 1. Principles

- **E1. Pure.** A run is a function of (source, notation, bindings,
  limits, language version). No clock, randomness, I/O, environment or
  state shared between runs.
- **E2. Same answer everywhere.** Any two conforming engines give, for
  the same run, the same exact values (identical text), approximate
  values within the tolerance of `calculatrix_mathematics.md`,
  section 3, and the same error id. Only a decision inside the band of
  that section may differ.
- **E3. Exact unless marked.** A value is exact or approximate as a
  whole, and its text says which. An approximate value never becomes
  exact on its own.
- **E4. Nothing silent.** A limit, a domain problem or a loss of
  exactness the program did not ask for is an error with an id, never
  a quiet fallback.
- **E5. Bounded.** Every run finishes or stops with a `limit_*` error.
  No `try` catches a `limit_*` error.
- **E6. Data is never code.** Values reach a program only through
  bindings, never by splicing text into the source.

## 2. Objects and lifecycle

| Object | SQLite analogue | Role |
|---|---|---|
| `Engine` | `sqlite3*` connection | Holds the configuration: limits and language version. Immutable once open. |
| `Program` | `sqlite3_stmt*` | A checked, reusable program. Immutable; safe to share and to run concurrently. |
| `Session` | none | One program written in parts, as a document or a calculator writes it (section 8). |

```
open(config)                          -> Engine  | Error
Engine.info                           -> EngineInfo
Engine.prepare(source, notation)      -> Program | Error   # parse and check, no execution
Engine.eval(source, notation, bindings) -> Result | Error
Engine.session(bindings)              -> Session
Program.run(bindings)                 -> Result  | Error   # no state survives
Program.parameters                    -> [ParameterInfo]
Program.definitions                   -> [DefinitionInfo]
Program.rpn                           -> text
Session.append(source, notation)      -> Result  | Error
```

- **E7.** `prepare` never runs code. Every error of phase `prepare`
  (`language.md`, section 8) is reported here, never later.
- **E8.** `run` with a missing, an undeclared or an invalid binding
  fails before running anything, with a `binding_*` error.
- **E9.** A `Program` can run any number of times; runs never observe
  each other. The engine keeps no state, so there is no `reset` and no
  `finalize`.
- **E10.** `Engine.eval(source, notation, bindings)` is by definition
  `prepare(source, notation).run(bindings)`.
- **E29. Notation is explicit.** `notation` is `rpn` or `infix`, and
  every call that takes a source requires it. The engine never guesses
  the notation from the text.
- **E30. Translation is observable.** `Program.rpn` is the RPN text of
  the program: for an infix program its translation (`language.md`,
  section 9.3), byte for byte the same in every engine; for an RPN
  program the source with comments dropped and tokens separated by one
  space.
- **E31. Definitions.** `Program.definitions` lists every function of
  the program with its name, its stack effect and the span of its
  definition, so a linter, a language server or an agent can work
  without running it.

`Program.call`, a function of a program called by name, is not in this
version (`language.md`, section 12). A host calls a function by
appending a call to a session.

## 3. Configuration and limits

Like `sqlite3_limit`: every limit has a default and its own error id.

| Limit | Default | Error id |
|---|---|---|
| `maxDigits`: digits of a numerator or denominator of any value | 10 000 | `limit_digits` |
| `maxSteps`: steps of one run (`language.md`, section 6) | 1 000 000 | `limit_steps` |
| `maxStackDepth`: values on the stack | 10 000 | `limit_stack` |
| `maxSourceLength`: bytes of the source | 1 048 576 | `limit_source` |
| `maxCallDepth`: nested function calls | 1 000 | `limit_calls` |

- **E11.** Limits are part of the run's identity (E1). Steps and digits
  are counted by the language specification, never by the engine's
  internals, so a limit stops at the same point on every engine.
- **E12.** `config.languageVersion` pins the language version. A
  program that uses a feature of a newer version fails in `prepare`
  with `unsupported_feature`.
- **E32. Maxima belong to each engine.** Every engine accepts at least
  the default of each limit, and reports in `Engine.info` the largest
  value it accepts. A host may set any value from 1 up to that maximum;
  `open` with a value outside it fails with `limit_unsupported`, and no
  engine lowers or raises a limit on its own. A program that runs
  within the defaults runs the same on every engine.

## 4. Values

The language has one value type, the matrix: exact or approximate, and
possibly carrying a boolean mark (`language.md`, section 3).

- **E13. Text.** Every value has one text, defined in `language.md`,
  section 3: `-7`, `1/3`, `[[1 2] [3 4]]`, `~0.1`, `true`. The text of a
  value, read as a literal, gives the value back. An exact value has
  the same text in every engine.
- **E14. JSON form.** In JSON a value is its text, as a string:
  `"1/3"`, `"~1.4142135623730951"`, `"true"`. Values never travel as
  JSON numbers, because a JSON number is a double in most hosts.
- **E15. Host mapping.** Each engine documents how values map to its
  host and offers helpers to read them (exactness, size, entries):
  arbitrary precision integers and rationals for exact entries, the
  host's double only for approximate ones. Turning an exact value into
  a double is an explicit host call, never the default (E4).
- **E16. Approximate text.** The text of an approximate value reads
  back, in the engine that wrote it, as the same doubles. The shortest
  such decimal (shortest round-trip) is recommended, not required:
  engines compare approximate values within a tolerance (E2), never by
  text.

## 5. Bindings

- **E17.** A program declares each value it receives with `parameter`
  (`language.md`, section 4.6): `:price parameter` in RPN, `parameter
  price` in infix. Inside the program a parameter is used as a bare
  word.
- **E18.** Bindings are by name only, never by position. A host passes
  each value as the text of a matrix literal, or as a value its engine
  returned, which stands for its text. The text is read as a literal,
  never as a program; anything else is `binding_invalid`.
- **E19.** `Program.parameters` lists the name and the span of every
  parameter the program declares, in order, so a host can check a call
  before running it.

## 6. Results

```json
{
  "stack": ["1/3", "~1.4142135623730951"],
  "steps": 4
}
```

- **E20.** The result is the whole final stack, bottom first, so the
  last value is the top of the stack. `Result.single()` is a
  convenience that fails with `result_not_single` unless exactly one
  value remains.
- **E21.** `steps` is reported so a host can size `maxSteps` from data.

## 7. Errors

```json
{
  "error": {
    "id": "stack_underflow",
    "phase": "prepare",
    "message": "add needs 2 values, found 1.",
    "span": {"offset": 2, "line": 1, "column": 3, "length": 3},
    "stack": [],
    "hint": "Push another value before add."
  }
}
```

- **E22.** `id` is a stable snake_case id and is the contract; `message`
  and `hint` are for people and agents and may change. Tests compare
  ids, spans and stacks, never message text.
- **E23.** `phase` is one of `prepare`, `binding`, `run` or `limit`
  (`language.md`, section 8), plus `open` for `limit_unsupported`.
- **E24.** `span` points into the source the host passed, in its own
  notation, by the rules of `language.md`, section 8; it is absent for
  an error that is about no place in the text. For an error
  inside a function, `span` points to the word that failed in the
  body, and `trace` lists the spans of the calls that led to it,
  innermost first.
- **E25.** `stack` is the stack just before the word or literal that
  failed, in the form of E20; for a `prepare` or `binding` error it is
  the stack the
  run would have started with. A failed run never returns partial
  results.
- **E26.** The ids of `language.md`, section 8, and of this contract
  keep their meaning. New ids may be added; none is ever reused for
  another meaning.

## 8. Sessions

A session is one program written in parts (`language.md`, section 4.7).

- **E33.** `Engine.session(bindings)` opens an empty session with the
  values for the parameters its parts may declare.
- **E34.** `Session.append(source, notation)` appends one part and runs
  the session from its start up to the end of that part. Its result is
  the stack after the part, with the steps counted from the start of
  the session.
- **E35.** A part that fails is not appended: the session stays as it
  was, and the error comes back. Its span points into that part.
- **E36.** Each part has its own notation; an infix part is appended as
  its translation (E30), so a document may mix RPN and infix parts.
- **E37.** A part that declares a parameter with no value in the
  session's bindings fails with `binding_missing`. A value that no part
  has declared yet is not an error, since a later part may declare it.
- **E38.** The result of `append` is always the result of running the
  whole session from its start. An engine may keep state between
  appends to avoid repeating work, as long as nothing shows it. To
  change a part already appended, a host opens a new session and
  appends the parts again.

## 9. Versions and conformance

- **E27.** Two versions travel separately: the language version (the
  specification) and the engine version (one implementation).
  `Engine.info` reports both, the conformance suite version the engine
  passes, and the maximum of every limit (E32).
- **E28.** A conforming engine passes 100% of the conformance suite for
  its declared language version. The suite, in `conformance/`, follows
  the format of `conformance.md`, and compares exact values by
  text, approximate values within the tolerance of
  `calculatrix_mathematics.md`, section 3, and errors by id, phase,
  span and stack. Partial engines declare which feature sets they
  implement, and `prepare` rejects everything else with
  `unsupported_feature`.

## 10. Host examples (illustrative)

The same program in both notations: a base price with tax, then a
discount.

```
:base parameter :tax parameter :discount parameter
base 1 tax add multiply 1 discount subtract multiply
```

```
parameter base
parameter tax
parameter discount
base * (1 + tax) * (1 - discount)
```

```dart
final engine = Engine.open(const EngineConfig(maxDigits: 1000));
final price = engine.prepare(source, Notation.infix);
final result = price.run({'base': '100', 'tax': '18/100', 'discount': '1/10'});
print(result.single()); // 531/5
```

```ts
const engine = open({ maxDigits: 1000 });
const price = engine.prepare(source, "infix");
price.run({ base: "100", tax: "18/100", discount: "1/10" }).single(); // "531/5"
```

```python
engine = calculatrix.open(max_digits=1000)
price = engine.prepare(source, "infix")
price.run(base="100", tax="18/100", discount="1/10").single()  # "531/5"
```

A calculator, line by line:

```dart
final session = engine.session({});
session.append('2 3', Notation.rpn);       // ["2", "3"]
session.append('add', Notation.rpn);       // ["5"]
session.append('drop drop', Notation.rpn); // stack_underflow; the session stays at ["5"]
```

## 11. Open questions

- **Q4.** The packaged artifact (the dacpac analogue) that an `Engine`
  could load in place of source. Pending the SQLite study in
  `docs/research/sqlite-as-embeddable-engine-model/`.

Settled: Q1 (script or library) by leaving libraries out of this
version (`language.md`, section 12); Q2 (the syntax for bindings) by
`parameter`; Q3 (approximate values across engines) by a tolerance
(E2, E16); Q5 (sessions) by section 8.
