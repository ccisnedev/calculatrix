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

## Open

O1–O3 were resolved as L22–L24, O9 as L25.

Next: O10 (function arity), then O4 (host parameters). Both change what
`prepare` checks, and `engine-api-contract.md` cannot be updated without
them.

- **O4. Parameters from the host.** `Program.run({price: 100})` makes
  `price` exist before the first line. To keep checking names in
  `prepare`, parameters may need a declaration such as `:price parameter`
  (contract Q2).
- **O5. Program variables vs session variables.** Variables that survive
  between lines of the interactive calculator (as in the HP variable
  menu) are a different thing from variables that live until the end of
  one program (contract Q5).
- **O6. Scope of the engine.** Exact numeric (integers, rationals,
  complex, matrices) or also symbolic (a CAS)? Cross-engine determinism
  (contract E2) is feasible for the first; symbolic simplification has
  no canonical form in general.
- **O7. Giac.** Proposed as a differential-testing oracle (the GPL-3
  license does not restrict use in a test harness that is not
  distributed), not as an engine. Not decided.
- **O8. Element-wise operations** (`.==`, `.*`) and what `<` means on
  matrices.
- **O10. Function arity.** E7 wants arity checked in `prepare`, but a
  function takes its arguments from the stack and nothing says how many.
  Options: a declared stack effect (`( x -- y )`), or counting the
  leading `:x var` of the body.
- **O11. Infix calls with several arguments.** The order of `f(a, b)` in
  RPN (`a b f`, so `b` is on top) and how infix defines a function
  (`function f(x, y) ... end`?).
- **O12. Control words.** The exact set (`if`, `ifelse`, `while`,
  `times`, `each`?) and their stack effects, and how infix spells them.
- **O13. Catchable errors.** Whether programs can catch errors other than
  `limit-*` (E5), and with which word.
- **O14. Infix grammar.** Precedence and associativity (is `-2^2` `-4`?),
  statement separators (`;`, newlines), comments.

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

- Bindings become variables that exist before the first line (L20, O4),
  not the `:price` push of E17.
- Value types become matrix, program, name; booleans carry a mark (L12).
- E7 holds in full: with L10 every name is checked in `prepare`.
- Host examples move from `:base :tax 1 + *` to RPN with `var` or to
  infix.
