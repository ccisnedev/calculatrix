# Engine API contract

Status: **draft 0.1**, under review. Nothing here is implemented yet; the
last section maps it to today's `calculatrix_core`.

Model: SQLite. A language with one specification, and one engine per host
language (Dart, TypeScript, Python, Rust...). The host passes program text,
binds named values, runs it and reads typed results. Every engine passes
the same conformance suite; this contract is what that suite tests at the
API boundary.

Each clause has an id (`E1`, `E2`...) so tests and reviews can cite it.

## 1. Principles

- **E1. Pure.** A run is a function of (source, bindings, limits, language
  version). No clock, randomness, I/O, environment or state shared
  between runs.
- **E2. Same answer everywhere.** Any two conforming engines return the
  same result, or the same error id, for the same run. For exact values
  this is identity of the canonical text (section 4).
- **E3. Exact unless marked.** Every value carries an `exact` flag. An
  approximate value never becomes exact again.
- **E4. Nothing silent.** A limit, a domain problem or a degradation of
  exactness the program did not ask for is an error with an id, never a
  quiet fallback.
- **E5. Bounded.** Every run finishes or stops with a `limit-*` error.
  Programs cannot catch `limit-*` errors.
- **E6. Data is never code.** Values reach a program only through
  bindings, never by splicing text into the source (the lesson of SQL
  injection).

## 2. Objects and lifecycle

| Object | SQLite analogue | Role |
|---|---|---|
| `Engine` | `sqlite3*` connection | Holds configuration: limits, language version. Immutable once open. |
| `Program` | `sqlite3_stmt*` | A validated, reusable program. Immutable; safe to share and to run concurrently. |
| `Run` | one `sqlite3_step` sequence | One execution with its bindings. Produces a `Result` or an `Error`. |

```
open(config) -> Engine
Engine.prepare(source)            -> Program | Error      # parse + check, no execution
Program.run(bindings)             -> Result  | Error      # E1: no state survives
Program.call(name, args)          -> Result  | Error      # library programs (open question Q1)
Program.parameters                -> [ParameterInfo]      # names the program expects
Program.definitions               -> [DefinitionInfo]     # names, stack effects, docs
```

- **E7.** `prepare` never executes code. All syntax errors and every check
  that does not depend on values (unknown words, arity, declared stack
  effects) are reported here, never later.
- **E8.** `run` with missing, extra or ill-typed bindings fails before
  executing anything, with `binding-*` errors.
- **E9.** A `Program` can run any number of times; runs never observe
  each other. (Unlike SQLite there is no database: the engine is
  stateless, so there is no `reset` and no `finalize`.)
- **E10.** There is a one-shot convenience, `Engine.eval(source, bindings)`,
  equal by definition to `prepare(source).run(bindings)`.

## 3. Configuration and limits

Like `sqlite3_limit`: every limit has a default, a hard maximum, and its
own error id.

| Limit | Default | Error id |
|---|---|---|
| `maxDigits`: digits of any integer, numerator or denominator (D55) | 10 000 | `limit-digits` |
| `maxSteps`: words executed in one run | to define | `limit-steps` |
| `maxStackDepth` | to define | `limit-stack` |
| `maxSourceLength`, in bytes | to define | `limit-source` |
| `maxCallDepth` (once definitions exist) | to define | `limit-calls` |

- **E11.** Limits are part of the run's identity (E1). A step is counted
  by the specification, never by the engine's internals, so `maxSteps`
  fails at the same point on every engine.
- **E12.** `config.languageVersion` pins the spec version. A program that
  uses a newer feature fails in `prepare` with `unsupported-feature`.

## 4. Values

Types the host sees: `integer`, `rational`, `complex` and `matrix`, each
exact or approximate. A scalar is a 1×1 matrix inside the language; at the
boundary an engine returns it as a scalar.

- **E13. Canonical text.** Every value has exactly one canonical text,
  the same in every engine: `-7`, `1/3` (lowest terms, sign on the
  numerator), `[[1 2] [3 4]]`. The canonical text of a value is a valid
  program that pushes that value back.
- **E14. JSON form.** `{"type": "rational", "exact": true, "text": "1/3"}`.
  Exact values travel as text, never as JSON numbers, because a JSON
  number is a float in most hosts.
- **E15. Host mapping.** Each engine documents how values map to its host:
  `BigInt`, its own rational type, `double` only for approximate values.
  Mapping an exact value to a float is an explicit host call that is
  never the default (E4).
- **E16. Approximate values.** Open question Q3: whether their canonical
  text must also be identical across engines (shortest round-trip IEEE 754
  binary64, as Ryu does) or only within a tolerance.

## 5. Bindings

- **E17.** A program declares what it receives. Syntax is open (Q2); the
  working spelling is `:price` for "push the value bound to `price`".
- **E18.** Bindings are by name only, never by position. A host passes
  values (section 4) or canonical text; text is parsed as a value literal,
  never as a program.
- **E19.** `Program.parameters` lists every name the program expects,
  with its expected type when the program declares one, so a linter, a
  language server or an agent can check a call before running it.

## 6. Results

```json
{
  "stack": [
    {"level": 2, "type": "rational", "exact": true,  "text": "1/3"},
    {"level": 1, "type": "rational", "exact": false, "text": "1.4142135623730951"}
  ],
  "steps": 4
}
```

- **E20.** The result is the whole final stack, level 1 on top, as
  `cx --json` prints it today. `Result.single()` is a convenience that
  fails with `result-not-single` unless exactly one value remains.
- **E21.** `steps` is reported so a host can size `maxSteps` from data.

## 7. Errors

```json
{
  "error": {
    "id": "stack-underflow",
    "phase": "run",
    "message": "+ needs 2 values, found 1.",
    "span": {"offset": 2, "line": 1, "column": 3, "length": 1},
    "stack": [{"level": 1, "type": "integer", "exact": true, "text": "1"}],
    "hint": "Push another value before +."
  }
}
```

- **E22.** `id` is stable kebab-case and is the contract; `message` and
  `hint` are for humans and agents and may change. Tests compare ids,
  spans and stacks, never message text.
- **E23.** `phase` is one of `prepare`, `binding`, `run` or `limit`, the
  same phase tags the conformance suite uses.
- **E24.** `span` points into the source passed to `prepare`. For an error
  inside a definition it points to the definition, and a `trace` lists the
  call sites (once definitions exist).
- **E25.** `stack` is the stack at the moment of the failure. A failed run
  never returns partial results.
- **E26.** Current ids (`CalculatrixErrorId`) keep their meaning. New ids
  are added, and none is ever reused for another meaning.

## 8. Versions and conformance

- **E27.** Two versions travel separately: the language version (the spec)
  and the engine version (one implementation). `Engine.info` reports both,
  plus the conformance suite version the engine passes.
- **E28.** A conforming engine passes 100% of the conformance suite for its
  declared language version. Partial engines declare which feature sets
  they implement, and `prepare` rejects everything else with
  `unsupported-feature`.

## 9. Host examples (illustrative)

```dart
final engine = Engine.open(const EngineConfig(maxDigits: 1000));
final price = engine.prepare(':base :tax 1 + * :discount 1 swap - *');
final result = price.run({'base': '100', 'tax': '18/100', 'discount': '1/10'});
print(result.single().text); // 531/5
```

```ts
const engine = open({ maxDigits: 1000 });
const price = engine.prepare(":base :tax 1 + * :discount 1 swap - *");
price.run({ base: "100", tax: "18/100", discount: "1/10" }).single().text; // "531/5"
```

```python
engine = calculatrix.open(max_digits=1000)
price = engine.prepare(":base :tax 1 + * :discount 1 swap - *")
price.run(base="100", tax="18/100", discount="1/10").single().text  # "531/5"
```

## 10. Open questions

- **Q1. Script or library?** Either a program is a script that leaves a
  stack, or it is also a library of definitions the host calls by name
  (`Program.call('price', ...)`), like a stored procedure. The second
  option fits the vision better and changes `prepare`, so it should be
  decided before 0.20.
- **Q2.** The source syntax for receiving bindings (`:name`, a header
  declaration, or locals `-> base tax discount { ... }`).
- **Q3.** Whether approximate values must match bit for bit across engines
  (E16).
- **Q4.** The packaged artifact (the dacpac analogue) that `Engine` could
  load in place of source. Pending the SQLite study in
  `docs/research/sqlite-as-embeddable-engine-model/`.
- **Q5.** Whether an engine may also expose an interactive session (the
  calculator app's model) on top of this contract, or whether that stays
  host-specific.

## 11. Mapping to today's `calculatrix_core`

| Contract | Today |
|---|---|
| `Engine.eval` | `Calculatrix.evaluateRpnStack(tokens, maxDigits:)` |
| `prepare` / `Program` | Partly exists: `_compileRpnCommands` builds commands, but it is private and checks nothing beforehand |
| `maxDigits` | `ExactArithmetic.defaultMaxDigits`, `LimitExceededError` (D55) |
| Error ids | `CalculatrixErrorId`; a span is only `token` + `position`, with no line, column or phase |
| Result JSON | `cx --json` (`level`, `exact`, `value`); approximate values go out as JSON numbers, which E14 forbids |
| Bindings, `steps`, other limits | Do not exist |
