# Conformance suite

Format version: **0.1**, for language version 0.1.

The conformance suite says, case by case, what a conforming engine
gives. It belongs to no engine: every engine reads it from outside and
passes all of it for the language version it declares
(`engine-api-contract.md`, E28).

## 1. Where it lives

```
conformance/
  0.1/              one folder per language version
    examples.json   one file per topic
    errors.json
    sessions.json
```

Each file is a JSON array of cases, in UTF-8. A case belongs to one
language version; a new version copies the folder and changes it.

## 2. A case

```json
{
  "name": "newton_exact",
  "notation": "infix",
  "source": ["parameter s", "var x = s", "..."],
  "bindings": {"s": "2"},
  "limits": {"maxSteps": 1000},
  "rpn": ":s parameter s :x variable ...",
  "expect": {"stack": ["886731088897/627013566048"], "steps": 101}
}
```

| Field | Required | Meaning |
|---|---|---|
| `name` | yes | Unique in its file; snake_case. |
| `notation` | yes | `rpn` or `infix`. |
| `source` | yes | The program, as a list of lines joined with `\n` (no newline after the last). |
| `bindings` | no | Parameter names to value texts. Absent means none. |
| `limits` | no | Limits that differ from the defaults (`engine-api-contract.md`, section 3). |
| `rpn` | no | The expected `Program.rpn` (E30), compared byte for byte. |
| `expect` | yes | Either `stack` or `error`, below. |

**A result.** `expect.stack` is the final stack, bottom first, as value
texts (E14, E20). `expect.steps`, when present, is the expected step
count (`language.md`, section 6).

**An error.** `expect.error` has:

| Field | Required | Meaning |
|---|---|---|
| `id` | yes | The error id. |
| `phase` | yes | `prepare`, `binding`, `run` or `limit`. |
| `span` | no | `{"offset", "length"}`, by the rules of `language.md`, section 8. `null` states that the error has no span. |
| `stack` | no | The stack just before the word that failed (E25). |

Line and column follow from the offset, so a case does not repeat them.

## 3. A session

A case with `session` in place of `source` and `expect` runs one
session (`engine-api-contract.md`, section 8):

```json
{
  "name": "calculator_failed_line",
  "bindings": {},
  "session": [
    {"notation": "rpn", "source": ["2 3"], "expect": {"stack": ["2", "3"]}},
    {"notation": "rpn", "source": ["drop drop drop"],
     "expect": {"error": {"id": "stack_underflow", "phase": "prepare"}}},
    {"notation": "rpn", "source": ["add"], "expect": {"stack": ["5"]}}
  ]
}
```

Each part is appended in order and checked against its own `expect`.

## 4. Comparing

- **Exact values** match when their texts are identical.
- **Approximate values** match when both texts are approximate, both
  have the same shape, and the result X and the expected Y satisfy the
  tolerance of `calculatrix_mathematics.md`, section 3.1. Y is written
  as the double nearest to the true value.
- A boolean matches only a boolean: `true` is not `1`.
- A stack matches when it has as many values as expected and each one
  matches.
- An error matches when its id and phase are the expected ones, and
  its span and stack too when the case gives them.
- No case lies in the band of `calculatrix_mathematics.md`, section
  3.2, where either answer conforms.

## 5. Writing cases

- One behavior per case, named for what it checks.
- A case that comes from an example of `language.md` keeps its source
  and its result, so the spec and the suite cannot drift apart.
- Messages and hints are never compared.
