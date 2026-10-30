# Language decisions

Status: **living document**, under debate. It records what has been
decided about the calculatrix language and what is still open. When a
decision changes, this file is edited in place and the old decision moves
to "Superseded".

Related documents:

- `engine-api-contract.md`: the engine API (draft 0.1). Some clauses there
  predate these decisions; see "Impact on the engine contract".
- `../research/modern-stack-language-design/00-synthesis-and-recommendations.md`:
  the earlier modern-stack plan. Its quotations, definitions and control
  as words still apply; its `-> a b c { }` locals and infix bridge are
  superseded.
- `../research/modern-stack-language-design/05-case-against-the-stack.md`:
  the devil's-advocate brief that led to the two-notation model.

## Requirements

What the language must make possible. Every decision is checked against
them.

- **R1. Documents.** A Markdown file whose `calculatrix` blocks and
  `{{ }}` references form one program: the blocks run in order and
  share one session, the program takes its parameters from a JSON file
  given by the host, and running it produces a Markdown file with the
  results in place. A VS Code notebook runs the same program block by
  block. This bears on L29 (parameters), L30 (sessions) and L34–L37
  (infix grammar), and on how a block shows its result.
  Runme, which runs the shell blocks of a Markdown file in VS Code, was
  tried on 2026-10-29: on Windows it runs a block only in a terminal,
  each block is a separate process, and it has no `{{ }}`. So the
  notebook is our own, on the VS Code notebook API (roadmap stage 4).
- **R2. No ambiguity.** Every valid text has exactly one reading. When
  a short form could be read two ways, the explicit form is required.
  Every decision is checked against this.

## Decided

### Notations

- **L1. Two notations, one language.** The modern RPN is a complete
  programming language and the one that runs the calculator. The infix
  notation is a high-level way to write it, aimed at agents (human or AI)
  and at larger programs.
- **L2. Commands.** `cx <program>` and `cx eval <program>` take RPN.
  `cx eval rpn <program>` keeps working. `cx eval infix <program>` takes
  infix.
- **L3. One semantics.** The meaning of an infix program is the meaning
  of the RPN it translates to. The infix spec is its grammar plus its
  translation rules.
- **L4. Normative translation.** Every engine translates the same infix
  program to the same RPN text, byte for byte. Changing a translation is
  a language version change, even if results do not change.
- **L5. Compositional translation.** Each subexpression translates on its
  own, with no optimization:
  `T(x op y) = T(x) T(y) op`, `T(f(x)) = T(x) f`.
  `inv(a*a)` becomes `a a * inv`, never `a dup * inv`. Engines may
  optimize when executing the RPN, but never change results, error ids
  or step counts.
- **L6. Design order.** First the core (values, operations, errors,
  limits), then the RPN, then the infix as a translation.
- **L7. Every engine implements the RPN.** Since infix runs as RPN, an
  engine without the RPN cannot run infix.

### Types

- **L8. Three types.**

  | Type | Literal | Notes |
  |---|---|---|
  | matrix | `[[1 2] [3 4]]`, `5`, `1/3` | A scalar is 1×1. Booleans are matrices (L12). |
  | program | `{ x x * }` | A value; closes over its lexical scope (L16). |
  | name | `:x` | Used by the words that create or change names. |

- **L9. Name sigil.** A name literal starts with `:`. `x` pushes the value
  of `x`; `:x` pushes the name itself.
- **L10. Literal names only.** A word that takes a name (`var`, `assign`,
  `function`) takes it from a `:name` literal written in the program.
  Names are never computed, so `prepare` checks every name before
  running.
- **L11. Comparisons return booleans.** `[1 2] [1 3] ==` returns one
  boolean. Element-wise operations (`.==`) are deferred.
- **L12. Booleans, Julia model.** `true` and `false` are `[1]` and `[0]`
  carrying a boolean mark:
  - comparisons, `and`, `or`, `not`, `true` and `false` produce it;
  - stack moves and `var` keep it;
  - arithmetic drops it: `true true +` is `2`;
  - it does not affect equality: `true 1 ==` is `true`;
  - it prints as `true` or `false`, which is also its canonical text.
- **L13. Strict conditions.** `if`, `and`, `or`, `not` and every other
  word that takes a condition accept only marked booleans. `[1] { } if`
  is a type error.

### Names, variables and functions

- **L14. Words.** `variable` (alias `var`), `assign` (alias `=`),
  `function` (alias `fn`).
- **L15. Variables hold matrices only.** Programs get names through
  `function`, never through `var`.
- **L16. Lexical scope, with closures.** A name is visible where its
  definition appears earlier in the text. A program value keeps seeing
  the names of the place where it was written, wherever it runs.
- **L17. A variable lives until the end of its scope.** A variable
  defined at program level lives until the end of the program; one
  defined inside a function lives until that call returns (L22). Before
  its definition it does not exist: `x 1 :x var` is an error.
- **L18. Variables are mutable.** `assign` changes the value of an
  existing variable; assigning a name that was never defined is an
  error.
- **L19. No shadowing, no redefinition.** Defining a name that already
  exists is an error, whether it is a catalog word (`e`, `i`, `pi`,
  `inv`), a function, or a variable in the same or an enclosing scope.
- **L20. Same level as constants.** A user name is used exactly like
  `pi`: as a bare word. It differs only in lifetime: `pi` exists in every
  program, a variable only in the run that defines it.
- **L21. Functions.** `function` binds a program to a name. Functions may
  recurse and use lexical scope. Arguments come from the stack:

  ```
  { :x var  x x * 1 + } :f function     # f(x) = x^2 + 1
  3 f                                     # 10
  ```

- **L22. Two kinds of scope: the program and each function call.** Every
  call gets a fresh scope, so recursion works:

  ```
  { :n var  n 1 <= { 1 } { n 1 - fact n * } ifelse } :fact function
  3 fact                                  # 6
  ```

  Each call defines its own `n`. L19 still applies: a function cannot
  define a name that already exists where the function is written (its
  lexical enclosing scope), and the caller's variables are not visible
  inside it.
- **L23. `var` always takes a value.** There is no variable without a
  value, so there is no "read before assign" error. Each word has one
  arity:

  | Infix | RPN |
  |---|---|
  | `var a = 1` | `1 :a var` |
  | `a = a + 1` | `a 1 + :a assign` (alias `a 1 + :a =`) |

  `=` assigns and `==` compares, as in C and Julia.
- **L25. The translation uses full names.** Infix always translates to
  the real name of a word, never to an alias: `a = a + 1` becomes
  `a 1 + :a assign`, and `inv(a)` becomes `a inverse`. Aliases (`=`,
  `var`, `fn`, `inv`) are only a help for people and agents who already
  know those words. Clarity first.
- **L24. Closures capture by reference.** A program sees the current
  value of the variables it captured, not the value they had when it was
  written:

  ```
  1 :a var
  { a } :get function
  2 :a assign
  get                                     # 2
  ```

  A captured variable lives as long as some program still refers to it,
  even after the call that defined it returns.
- **L28. Function arity.** `prepare` knows how many values each function
  takes and leaves, with no new syntax:
  - **Inputs:** a function takes as many values as the `:name var` that
    open its body. Inside the body nothing reaches below them:
    `{ dup * } :sq function` takes 0 values, so its `dup` is an error in
    `prepare`. A function takes its arguments by name, never by touching
    the caller's stack. Stack words outside functions are unchanged.
  - **Outputs:** what the body leaves is deduced from the stack effects
    of the words it uses (the command registry, and L28 for functions).
    Both branches of a conditional must leave the same number of values;
    otherwise `prepare` reports an error.
  - **Recursion:** the branch that does not recurse fixes the effect,
    and the recursive branch is checked against it. In `fact` (L22),
    `{ 1 }` fixes 1 → 1 and `{ n 1 - fact n * }` is checked with it.

  This is the shape infix `function f(x, y)` translates to (L5). The
  order in which several arguments bind is L31.
- **L29. Parameters.** A program declares the values it receives from
  its host with `parameter`: `:price parameter` in RPN,
  `parameter price` in infix. So the program says what it needs and can
  be read on its own (R1).
  - A parameter is used as a bare word, like a variable (L20), and is
    visible from its declaration on (L16). It cannot be assigned, and
    its name follows L19.
  - Parameters are declared at program level, never inside a function.
  - `prepare` checks every name as usual. `run` checks the values the
    host gives against the declarations before executing anything: a
    missing or an undeclared value is a `binding-*` error (contract E8).
- **L30. A session is one program written in parts.** The blocks of a
  document and the lines of the calculator (app or REPL) are appended to
  one program: variables, functions and the stack carry on, and L16–L29
  apply unchanged. There are no session variables of another kind.
  - **Notebook:** running a block runs the document from its start up to
    that block, so what a block shows is always what the document gives
    read top to bottom, with no hidden state.
  - **Calculator:** lines are appended. An existing variable changes with
    `assign`; `var` on an existing name is an error that says so (L19).
  - **Persistence:** none between `cx` invocations. A session is a
    document or an open window.
- **L31. Argument order.** `var` always takes the value on top of the
  stack, inside a function as anywhere else. `f(a, b)` is `a b f`, so a
  function names its arguments last to first:

  ```
  { :y var :x var  x y - } :minus function
  5 3 minus                               # 2
  ```

  Infix `function minus(x, y) ... end` translates to that body (L5).

- **L32. Control words.** Four words, each taking programs `{ }` as
  arguments, with no new syntax:

  | RPN | Infix | Effect (L28) |
  |---|---|---|
  | `c { A } if` | `if c ... end` | `A` leaves the stack as it found it |
  | `c { A } { B } ifelse` | `if c ... else ... end` | `A` and `B` leave the same |
  | `{ C } { A } while` | `while c ... end` | `C` leaves one boolean; `A` leaves the stack as it found it |
  | `1 10 { :k var ... } for` | `for k in 1:10 ... end` | the body takes the index and leaves the stack as it found it |

  - Conditions are marked booleans (L13). Every turn of a loop counts as
    steps toward the evaluation limits.
  - Left out: `times` (covered by `for`), `each` over entries (`for` with
    an indexed access word, which the vocabulary still lacks), `break`
    and `return` (they complicate L28 and `while` covers them).
  - How infix writes the range `1:10` is O14.

- **L33. Catching errors.** `{ A } { E } try` runs `A`; if it fails,
  the stack returns to what it was before `A`, and `E` runs with the
  error id on top as a name (`:singular-matrix`), with no error type of
  its own (L8).

  ```
  { a inverse } { :e var  a pseudo-inverse } try
  ```

  - What `A` assigned before failing stays assigned; only the stack is
    restored.
  - Effect (L28): `A`, and `E` after taking the error name, leave the
    same.
  - Infix: `try ... catch e ... end` translates to
    `{ ... } { :e var ... } try`.
  - Not caught: `limit-*` errors (contract E5) and errors of `prepare`,
    which come before anything runs.

- **L34. Lines and comments.**
  - `#` starts a comment that runs to the end of the line, in both
    notations. It survives the quoting of bash, PowerShell and cmd.
  - Infix separates statements with a newline, or with `;` to put
    several on one line. A statement continues on the next line while a
    parenthesis or a bracket is open.
  - Infix closes blocks with `end` (L32, L33).
  - In RPN a newline is just whitespace and `;` has no use.

- **L35. Infix precedence.** From highest to lowest:

  | Level | Operators | Associativity | Example |
  |---|---|---|---|
  | 1 | calls `f(x)`, `( )` | | |
  | 2 | `^` | right | `2^3^2` is `2^9` |
  | 3 | unary `-` | | `-2^2` is `-4` |
  | 4 | `*` `/` | left | `a/b*c` is `(a/b)*c` |
  | 5 | `+` `-` | left | |
  | 6 | `==` `!=` `<` `<=` `>` `>=` | none | `a < b < c` is an error |
  | 7 | `not` | | |
  | 8 | `and` | | |
  | 9 | `or` | | |

  `and`, `or` and `not` are words, as in RPN.

- **L36. Multiplication is always `*`.** Juxtaposition never
  multiplies: `2x` is an error that says `write 2*x`. Allowing a number
  before a name would give `1/2x`, `2^2x` and `2e` two readings (R2).
  Since `2x` is an error today, allowing it later breaks nothing.

- **L37. Ranges.** `for k in 1:n ... end` translates to
  `1 n { :k var ... } for`; the range includes its end, as in Julia and
  MATLAB.
  - A range exists only after `for ... in`; it is not a value, so the
    types stay three (L8), and `:` anywhere else in infix is an error.
  - A start greater than the end runs the body zero times: `1:0` is
    empty, so `1:n` works for `n = 0` with no special case.
  - No step for now: `1:2:10` puts the step in the middle, an easy
    misreading. A step is decided on its own if needed.

- **L38. Percent is a word, not `%`.** `200 15 percent` is `30` (15 %
  of 200), and infix writes `percent(200, 15)`. `%` is not part of the
  grammar of either notation: it reads as percent on a calculator and
  as modulo in Python, C and JavaScript (R2).
  - The app's BASIC keypad behaves like the Casio pocket calculator it
    follows (`../research/casio-hl-820lv.md`): `200 + 10 %` is `220`.
    That is the keypad's behavior, not the language's, so it lives with
    the keypad, not in the core's infix.
  - `%` is not an alias either: `7 3 %` meant as modulo would give
    `0.21` with no error. It is an error that says to write `percent`.

- **L39. Comparisons.**
  - `<`, `<=`, `>` and `>=` take real scalars: a matrix λI of any size,
    1×1 included, compares as λ (`[[2 0] [0 2]] 3 <` is `true`,
    `i i * 0 <` is `true`). A complex value `aI + bJ` with `b ≠ 0` and
    every other matrix are an error: they have no order. λI is
    recognized only when every entry off the diagonal is exactly 0.
  - `==` and `!=` take exact values only, and compare them strictly:
    same shape, every entry equal. An approximate operand is an error
    that says to compare a difference with `<`
    (`abs(x - y) < 1e-10`), since equality of approximations is almost
    always a bug.
  - Element-wise operations (`.*`, `.==`) are deferred past spec 0.1;
    `.*` is an error today, so adding them later breaks nothing.

### Scope of computation

- **L26. Numeric and symbolic, matrices first.** The language computes
  exactly with numbers and symbolically with expressions (a CAS). In
  both, the matrix is the unit of computation.
- **L27. Pure Dart, Giac only as oracle.** The CAS is written in pure
  Dart so the engine stays MIT; Giac is never linked and only checks
  the engine in tests, under a clean-room policy (ADR 0004).

## Open

O1–O3 were resolved as L22–L24, O9 as L25, O7 as L27, O10 as L28,
O4 as L29, O5 as L30, O11 as L31, O12 as L32, O13 as L33,
O14 as L34–L37, O15 as L38, O8 as L39.

Spec 0.1 can be written. O6 is deferred to roadmap stage 8 (symbolic
computation); spec 0.1 does not depend on it.

- **O6. Canonical symbolic results.** How symbolic results stay
  identical across engines (contract E2), since simplification has no
  canonical form in general.

## Superseded

| Was | Replaced by | Why |
|---|---|---|
| Locals `-> a b c { }` and the infix bridge `'...'` (synthesis 00) | `var` (L14, L17) | Infix is its own notation (L1); `var` is a word, not syntax. |
| `tag` with a count: `[1] :a tag { a } 1 execute` | `var` defining a variable in scope | A defined variable is simpler and needs no count. |
| A tagged-value type on the stack | Removed | `var` binds directly; nothing is left on the stack. |
| `{a}` as a name | `:a` (L9) | `{ }` is the program type. |
| Single assignment | Mutable variables (L18) | Variables must be usable like in other languages. |
| `true` as a plain alias of `[1]` | Marked boolean (L12) | So `cx '1 2 <'` prints `true` and `if` stays strict. |
| Every variable lives until the end of the program | Until the end of its scope (L17, L22) | Otherwise a recursive call redefines its own variables. |

## Impact on the engine contract

Pending edits to `engine-api-contract.md`, to be made once the open
questions above settle:

- Bindings are declared with `parameter` (L29) and used as bare words,
  not the `:price` push of E17; this settles Q2.
- Value types become matrix, program, name; booleans carry a mark (L12).
- E7 holds in full: with L10 every name is checked in `prepare`, and
  with L28 the arity of every function.
- Host examples move from `:base :tax 1 + *` to RPN with `var` or to
  infix.
- A session is part of the contract (L30): the engine offers appending a
  block to a program and running up to it; this settles Q5.
