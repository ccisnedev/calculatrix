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

- **L8. One type of value, two written forms.** The stack holds only
  matrices. Programs and names are written in place, as arguments of
  the words that take them:

  | Form | Literal | Written just before |
  |---|---|---|
  | matrix | `[[1 2] [3 4]]`, `5`, `1/3` | A value. A scalar is 1×1. Booleans are matrices (L12). |
  | program | `{ x x * }` | `function`, `if`, `ifelse`, `while`, `for`, `try`; it closes over its lexical scope (L16). |
  | name | `:x` | `variable`, `assign`, `function`, `parameter`, `try`. |

  A `{ }` or a `:x` anywhere else is a `syntax_error`: `true { 1 }
  { 2 } swap ifelse` and `:x 5 swap var` have no meaning. So `prepare`
  always knows which program each word runs and which name it gets.
  No word runs a loose program (there is no `execute`); program values
  can be opened later without breaking anything.

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

- **L22. Each function call has its own scope.** Every call gets a
  fresh scope, so recursion works (the other scopes are in L53):

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

  A program never leaves the place where it is written (L8), so a
  captured variable never outlives its scope.
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
    missing or an undeclared value is a `binding_*` error (contract E8).
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
    the indexed access words of L44), `break`
    and `return` (they complicate L28 and `while` covers them).
  - Infix writes the range `1:10` as L37 says.

- **L33. Catching errors.** `{ A } :id { E } try` runs `A`; if it fails
  with the error `id`, the stack returns to what it was before `A` and
  `E` runs. Any other error goes on as if there were no `try`.

  ```
  { a inverse } :singular_matrix { a size zeros } try   # zeros if a is singular
  ```

  - The program names the failure it expects. There is no "catch any
    error", which hides failures nobody expected; two ids take two
    nested `try`.
  - The id is a name literal written in the program (L10); a name that
    is no catchable id is an error in `prepare`. Variables still hold
    matrices only (L15), and `E` receives nothing on the stack.
  - What `A` assigned before failing stays assigned; only the stack is
    restored.
  - Effect (L28): `A` and `E` leave the same.
  - Infix: `try ... catch singular_matrix ... end` translates to
    `{ ... } :singular_matrix { ... } try`. After `catch` comes an error
    id, not a variable; its place in the grammar says so, with no `:`.
  - Not caught: `limit_*` errors (contract E5) and errors of `prepare`
    and of binding, which come before anything runs.

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

- **L40. Words join with `_`, never `-`.** `frobenius_norm`,
  `append_cols`, `delete_row`, and the same for user names
  (`vat_rate`). In infix `a-b` is a subtraction, so a hyphen inside a
  name would give `frobenius-norm(a)` two readings (R2). Each word has
  one spelling in both notations. Error ids follow the same rule,
  since `try` hands them to the program as names: `singular_matrix`,
  `limit_exceeded`.

- **L41. Names are case-sensitive.** `A` and `a` are two names, as a
  matrix and a vector are in mathematics. Every word of the vocabulary
  is lowercase: `PI` is `unknown_word`, and the message suggests `pi`.
  Engines compare names as written, with no case folding to specify.

- **L42. A program leaves the stack.** The result is the whole final
  stack, level 1 on top (contract E20).
  - An empty stack is a valid result: a block that only defines
    functions leaves nothing, and that is not an error.
  - A notebook block shows the stack as it is after the block, as the
    calculator does. In infix `var b = ...` leaves nothing and an
    expression on its own line (`a*b`) leaves its value; `drop` hides
    one. There is no `show` or `print` word, so the stack is the only
    output (E1).

- **L43. Several results in infix.** A word that leaves several values
  (`lu`, `qr`, `diagonalize`) is written with several names before `=`:
  `var p, l, u = lu(a)` translates to `a lu :u var :l var :p var`, by
  L31; `a, b = qr(m)` translates to `m qr :b assign :a assign`.
  - The names read in the order the word leaves its values, and their
    count must match what it leaves: `var p, l = lu(a)` is an error in
    `prepare`.
  - Inside an expression a call must leave exactly one value:
    `x + lu(a)` is an error in `prepare` that suggests
    `var p, l, u = lu(a)`.

- **L44. Every word has one stack effect, known before running.**
  - A count is a literal written just before its word: `1 2 3 3 vector`,
    `3 pick`, `2 roll`. A computed count (`n vector`) is an error in
    `prepare`. In infix `vector(1, 2, 3)` translates to
    `1 2 3 3 vector`: the translation adds the number of arguments.
  - `rows`, which leaves one value per row plus the count, is replaced
    by words of fixed effect: `row` (`A i → row i`), `column`
    (`A j → column j`), `size` (`A → r c`) and `entry`
    (`A i j → a_ij`). They are the indexed access that `for` needed to
    walk a matrix (L32).

- **L45. Names are explicit; symbols are aliases.** Every symbol is an
  alias of a word with a full name, so infix can translate to it (L25):
  `==` `equal`, `!=` `not_equal`, `<` `less`, `<=` `less_equal`,
  `>` `greater`, `>=` `greater_equal`. `a < b` translates to
  `a b less`. Names are written out, never abbreviated (`column`, not
  `col`); short forms are aliases. So these words take a full name and
  keep the short one as an alias:

  | Was | Name | Aliases |
  |---|---|---|
  | `append-cols` | `append_columns` | |
  | `delete-col`, `duplicate-col`, `move-col` | `delete_column`, `duplicate_column`, `move_column` | |
  | `sqrt` | `square_root` | `sqrt`, `√` |
  | `exp` | `exponential` | `exp` |
  | `ln` | `natural_logarithm` | `ln` |
  | `approx` | `approximate` | `approx`, `num` |
  | `rref` | `reduced_row_echelon_form` | `rref` |

  Mathematical symbols (`pi`, `e`, `i`) and names of what a word
  produces (`lu`, `qr`: the matrices L, U and Q, R) are not
  abbreviations and stay.

- **L46. Absolute value.** `absolute_value` (alias `abs`) takes a real
  scalar, λI of any size as in L39, and leaves |λ| as 1×1:
  `abs(x - y) < 1e-10`. A complex value or any other matrix is an
  error that suggests `frobenius_norm` for a matrix. The modulus of a
  complex number waits until complex numbers are decided.

- **L47. Error ids.** One id per distinct cause, so a `try` or an agent
  knows what failed without reading the message. Grouped by the phase
  that raises them (contract E23):

  | Phase | Id | Raised for |
  |---|---|---|
  | prepare | `syntax_error` | malformed text, `2x` (L36), `%` (L38), `:` outside `for` (L37), `a < b < c` (L35) |
  | prepare | `unknown_word` | a name not defined at that point, `:a assign` with no `var` before it included |
  | prepare | `name_exists` | defining a name that exists (L19) |
  | prepare | `not_assignable` | `assign` on a parameter, a function or a constant |
  | prepare | `stack_effect` | an inconsistent stack effect: branches that differ, a function reaching below its arguments, a call leaving several values inside an expression, a count of names that does not match, a count that is not a literal |
  | prepare | `stack_underflow` | a word with fewer values below it than it takes, found by following the stack effects (L28, L44) |
  | prepare | `parameter_in_function` | `parameter` inside a function (L29) |
  | prepare | `unsupported_feature` | a feature of a newer language version |
  | binding | `binding_missing`, `binding_unknown`, `binding_invalid` | a declared value missing, a value not declared, a text that is not a literal |
  | run | the mathematical ids | `singular_matrix`, `dimension_mismatch`, ... |
  | run | `type_mismatch` | an index or a divisor of the wrong kind, as today |
  | run | `not_boolean` | a condition, `and`, `or` or `not` on a value that is not a marked boolean (L13) |
  | run | `not_ordered` | `<`, `<=`, `>`, `>=` or `absolute_value` on a value that is not a real scalar (L39, L46) |
  | run | `approximate_equality` | `==` or `!=` with an approximate operand (L39) |
  | limit | `limit_digits`, `limit_steps`, `limit_stack`, `limit_source`, `limit_calls` | the limits of the contract; `limit_digits` replaces `limit-exceeded` |

- **L48. Infix has no prefix operators but unary `-` and `not`.** `√` is
  an alias of `square_root` and is called like any word: `√(9)`,
  `sqrt(9)`, `square_root(9)`; in RPN `9 √`. `√9` is a `syntax_error`
  that says `write √(9)`, so `√4*2` has no reading to guess.

- **L49. The document format has its own spec.** How a Markdown file
  marks its blocks, what `{{ }}` holds, how a block names its notation,
  the JSON of parameters and the output file are specified in roadmap
  stage 3, apart from the language. A document is one way of writing a
  program, like the `cx` command line or the app's keypad, so its
  format can change without a language version. What R1 needs from the
  language is L29, L30 and L42.

- **L50. A step is one written word run.** `limit_steps` stops at the
  same point on every engine (contract E11) because the spec counts:
  - pushing a literal (`3`, `[[1 2]]`): 1; a program or a name written
    in place is part of its word and counts nothing;
  - running a word of the vocabulary: 1, whatever work it does;
    `square_root` is 1 even if an engine runs it as `0.5 power`;
  - calling a user function: 1, plus the steps of its body;
  - a control word (`if`, `ifelse`, `while`, `for`, `try`): 1, plus the
    steps of each program it runs, every turn of a loop included.

  Infix counts on its translation (L3): `a + b` is 3 steps. Steps are
  not weighted by cost; the work inside one word is bounded by
  `limit_digits` and the size of matrices.

- **L51. Matrix literals hold numbers only.** A matrix with variables
  is built with words: `vector(x, y)`, `append_columns(a, b)`,
  `append_rows(a, b)`. Inside brackets whitespace separates entries,
  so `[a -b]` would have two readings (R2). A name inside brackets
  stays a `syntax_error`, so allowing expressions later, with
  mandatory commas (`[x, -y]`), breaks nothing.

- **L52. Infix numbers carry no sign.** In infix `-` is always the
  operator: `-2` translates to `2 negate`, `3*-2` to
  `3 2 negate multiply`, `-2^2` to `2 2 power negate` (L35). The
  exponent may start with `-`, as in Julia and Python: `2^-2` is
  `2 2 negate power`. Signs inside a matrix literal belong to it
  (`[[1 -2]]`), and `~` keeps its sign after it (`~-0.1` is one
  literal). In RPN `-2` stays a literal.

- **L53. Three kinds of scope: the program, each function call, and
  each run of a control body.** Every time `if`, `ifelse`, `while`,
  `for` or `try` runs one of its programs, that run gets its own scope,
  as blocks do in Julia and Rust:
  - a name defined inside with `var` (the `k` of `for` included) ends
    with that run, so `for` defines `k` afresh
    each turn;
  - the names outside are visible and can be assigned, so
    `s = s + k` works;
  - L19 holds: a body cannot define a name that exists outside it.
  - a function call still does not see its caller's variables.

  So `prepare` knows every name: after `c { 1 :x var } if`, `x` does
  not exist, whatever `c` was.

- **L54. Precisions made while writing spec 0.1.** Each follows from
  the decisions above or from R2:
  - `{` and `}` are tokens separated by whitespace; user names are ASCII
    (a letter, then letters, digits and `_`).
  - A malformed literal is `syntax_error`, and every error in a literal
    (`[]`, `1/0`, `~1e400`) is found by `prepare`, so no `try` catches
    it. A count is a positive integer literal; only the counts of
    `vector`, `pick` and `roll` decide an effect.
  - A run reports one error: the first phase that fails, and within
    `prepare` the first in the text.
  - The body of `for` takes the index. A recursive function with no branch that
    does not recurse is `stack_effect`.
  - The boolean mark is kept by stack words, `variable`, `assign` and
    reading a variable, and dropped by every other word.
  - The text of a program is its tokens separated by one space,
    comments dropped.
  - Pushing a variable is a step; the index that `for` pushes is not; a word that fails counts its step. `limit_calls`
    counts function calls only.
  - A parameter is declared outside any function or control body, and
    a host value is the text of a matrix literal.
  - In a calculator a line that fails is not appended. Limits count per
    run.
  - Infix: a call on its own line may leave several values; the header
    of `if`, `while` and `for` ends at the end of its line or `;`; the
    `-` of an exponent negates the whole power on its right
    (`2^-2^2` is `2^-(2^2)`); `-[[1 2]]` is `[[1 2]] negate`; `if`,
    `else`, `end`, `while`, `for`, `in`, `try`, `catch`, `function`,
    `var` and `parameter` are reserved.

- **L55. A function sees itself, and nothing else comes early.** The
  name of a function is visible inside its own body, so direct
  recursion works (`fact`, L22). Every other name is visible only after
  its definition: in `{ g } :f function { f } :g function` the `g`
  inside `f` is `unknown_word`. `prepare` checks names in one pass, top
  to bottom, with this one exception.

- **L56. No program reaches below where it starts.** The rule of
  functions (L28) holds for every `{ }`: a control body takes nothing
  from below the point where it starts, except the index that `for`
  gives it. So a body's effect is the number of values it leaves: none
  for `if`, `while` and `for`, one boolean for the condition of
  `while`, and the same number for both branches of `ifelse` and both
  programs of `try`. `5 true { 1 + } if` and `0 1 10 { + } for` are
  `stack_effect`; a body accumulates through a variable. Infix always
  produces such bodies.

### Mathematics independent of the engine

- **L57. Approximate results agree within a tolerance, not bit for
  bit.** The specification fixes the mathematical quantity each word
  approximates, never the algorithm or the order of floating-point
  operations. Exact results stay identical across engines (E2); an
  approximate result only has to be close enough (L58). This settles
  contract Q3: the text of an approximate value has to read back as
  the same double in the engine that wrote it, not to be the same
  text in every engine.

- **L58. Close enough is measured on the whole matrix.** An
  approximate result X is conforming when
  ‖X − Y‖ ≤ 1e-10 · ‖Y‖ + 1e-12, with Y the true value and ‖·‖ the
  infinity norm (the largest sum of absolute values in a row). A
  decision taken with a tolerance (a pivot ≤ 1e-12, two eigenvalues
  within 1e-10) is fixed only outside a band around its threshold;
  inside the band either answer conforms, and the conformance suite
  tests no case inside it.

- **L59. The pivot of `lu` is the largest entry, the first on a
  tie.** For exact and approximate values alike: the pivot of each
  column is its entry of largest absolute value on or below the
  diagonal, the uppermost when several tie. A column with no nonzero
  candidate is left as it is, so a singular matrix has a
  decomposition with a zero on the diagonal of U. Both paths give the
  same P outside the band of L58. The first nonzero pivot (the
  convention of exact algebra, P = I whenever possible) was weighed
  and set aside: it would make `a lu` and `a approximate lu` differ in
  structure, not only in rounding.

- **L60. `qr` needs full column rank.** `qr` leaves the reduced Q
  (m×n, orthonormal columns) and R (n×n, upper triangular, positive
  diagonal), which are unique when A has full column rank. A matrix
  without it is `rank_deficient`, a new error id.

- **L61. The eigenvectors of `diagonalize` are not scaled.** D holds
  the eigenvalues in descending order. For each eigenvalue λ, the
  columns of P are the basis of the null space of A − λI read from
  its reduced row echelon form: for each free column j, in increasing
  order, the vector with 1 at j, minus the entries of column j at the
  pivot columns, and 0 elsewhere. So `diagonalize` is exact when A is
  exact and every eigenvalue is rational.

- **L62. `limit_digits` applies to values, never to estimates.** A
  value that reaches the stack (a literal or the result of a word)
  with a numerator or denominator of more than `maxDigits` digits is
  `limit_digits`. What a word computes inside does not count. An
  engine may stop early only when it knows the result will exceed
  the limit, never because an upper bound says it might.

- **L63. Exact fractional powers come from a closed list of forms.**
  For an exact B and an exact non-integer exponent p/q, the result is
  exact when B is one of these forms and its rule gives a rational
  result: a scalar (with its complex principal value when negative),
  a diagonal matrix, a complex number with q = 2, or λI + N with N
  nilpotent (the finite binomial series, λ^(p/q) rational). Any other
  base gives the approximate result, even when a rational root
  exists. Guessing a rational from the approximate result and
  checking it was set aside: the guess depends on bits that L57 does
  not fix.

### Settled by the clean-room prototype

An interpreter written from the specs alone found where they let two
engines differ. Each decision below closes one of those places.

- **L64. An infix call takes exactly its arguments.** A call passes as
  many arguments as its word takes; more or fewer is `stack_effect` at
  the name of the call. So `f(x)` uses only what the reader sees:
  `add(1)` never adds the value below it. The count that `vector(...)`
  adds is not an argument. Letting a call reach into the stack, since
  an infix program means its translation, was set aside: it hides
  inputs from the reader (R2). A new id for this error was set aside
  too: `stack_effect` already names an effect that does not hold.

- **L65. A count is part of its word.** The count of `vector`, `pick`
  and `roll` is syntax, as a name before `variable` or a program
  before `if`: it is never pushed, counts no step and never shows in
  the stack of an error. `1 2 3 3 vector` is 4 steps, and so is
  `vector(1, 2, 3)`, whose count is not in the text. Pushing it as any
  other literal was set aside: a count must already be a literal
  written just before its word, so treating it as a value adds a case
  without adding anything a program can do.

- **L66. A 1×1 matrix is written as a scalar.** A value has one text,
  and a 1×1 matrix has the text of its scalar: `true transpose` is
  `1`, not `[[1]]`. Writing `[[1]]` when a matrix word made the value
  was set aside: the value would have to remember where it came from,
  a second mark beside the boolean one that its text could not show.

- **L67. Counts and permutations are exact.** `size`, `rank` and the
  P of `lu` give exact values even on an approximate operand: they are
  integers by definition, so `~[[1 2]] size zeros` works as
  `[[1 2]] size zeros` does. Making them approximate by contagion was
  set aside: an approximate size or rank means nothing, and every
  program that sizes a matrix from another would then need sizes that
  accept approximate values.

- **L68. Structure needs exact integers; an exponent goes by its
  value.** A count, an index, a size or a bound of `for` must be an
  exact integer, so the shape of a program never depends on rounding:
  `~2 identity` is `type_mismatch`, while `~0.1 ~0.2 + ~10 *`, which
  is 3.0000000000000004, would otherwise fail where `~3` works. L67
  keeps this from costing anything, since `size` and `rank` are exact.
  The exponent of `power` is a quantity, not structure: an approximate
  integer value takes the integer rows, so `-2 ~2 power` is ~4 and not
  a complex form. Requiring exact integers there too was set aside,
  since it turns `x ~2 power` into a complex form or `log_undefined`;
  deciding everything by value was set aside for structure, as above.

- **L69. A recursive function's effect is deduced without its
  recursive calls.** The bodies of `if`, `while` and `for` have their
  effect fixed by rule, so a recursive call inside them does not block
  the deduction; in `ifelse` and `try` the program without a recursive
  call fixes the effect of both; the whole body is then checked
  against the result. Allowing recursion only in `ifelse` and `try`
  was set aside: it rejects programs whose effect is known, such as
  `n 0 > { n 1 - f } if`, only to make the rule shorter to state.

- **L70. The call depth is the number of active calls.** A call that
  would make more than `maxCallDepth` function calls run at once is
  `limit_calls`. Counting only the nesting below the first call was set
  aside: the limit should mean exactly its number.

- **L71. Literals and bindings are checked for digits before the
  run.** A literal with more than `maxDigits` digits is `limit_digits`
  found by `prepare`, even in a branch that never runs, as every other
  error of a literal; a binding is checked before the run starts.
  Checking when the value is pushed was set aside: whether a program
  fails would depend on which branches run, and a binding would go
  unchecked until it is read.

- **L72. The phase says when an error was found.** `prepare` when the
  text alone shows it, `binding` when the host's values do, `run` and
  `limit` while running. So `0 pick` is `type_mismatch` of phase
  `prepare`, a literal over `maxDigits` is `limit_digits` of phase
  `prepare`, and `limit_source` is of phase `prepare`. A host learns
  from the phase whether the program text is wrong whatever the data,
  and `try` catches exactly the errors of phase `run`. Giving each id
  one fixed phase was set aside: `try` would then need an exception for
  run ids that `prepare` finds.

- **L73. `prepare` stops at the first error of a fixed order.** First
  the source length, then the reading of the whole text, then the
  checks of the RPN program word by word from left to right, a body
  before its control word; for infix, the order of its translation.
  Reporting the error with the smallest offset was set aside: it needs
  every error found, and then rules for errors that follow from an
  earlier one, such as an effect that cannot be known after an unknown
  word.

- **L74. A step is counted before it runs.** A word whose step would
  go over `maxSteps` does not run, so the limit prevents work instead
  of detecting it afterwards: `1 0 divide` with `maxSteps` 2 is
  `limit_steps`. Counting after the word ran was set aside: a costly
  word would run before the limit stopped it.

- **L75. In a session, a span says which part it points into.** An
  error in a function written in an earlier part points to the word
  that failed there, and its span carries the number of that part;
  `trace` shows the calls that led to it. Pointing always into the
  part being appended was set aside: a document or a language server
  would underline the call instead of the line that failed.

- **L76. A session's errors before running show its stack.** The
  stack of a `prepare` or `binding` error in a session is the stack
  after the last part appended, the one the calculator shows and the
  one `prepare` follows the depth from. The empty stack, read from
  "the session runs from its start", was set aside: it matches nothing
  the user sees.

- **L77. A boolean can be a binding.** A binding is the text of a
  matrix literal, `true` or `false`, so every result of a program can
  be passed back to another, mark included. Keeping booleans out of
  bindings was set aside: every host that chains programs would turn
  `true` into `1`, and the program would lose the mark where an `if`
  needs it.

- **L78. A body that takes too much points to the word that takes.**
  Inside a body, a word that takes values from below where the body
  starts is `stack_effect` at that word: `{ dup * } :sq function` points
  to `dup`, and `true { drop } if` is `stack_effect` at `drop` even on
  an empty stack. A body that leaves the wrong number of values points
  to its control word. Pointing always to the control word was set
  aside: it hides which word reached too far.

- **L79. A failed test shows the stack at the test.** When a control
  word fails on a value it tests, the stack of the error is the one at
  that test, with the tested value on top: `{ 1 } { } while` shows
  `1`, as `1 { } if` does. The stack before the control word started
  was set aside: it hides the value that failed and the turn it failed
  on.

- **L80. A diagonal base with entries ≥ 0 takes any positive power.**
  For a non-integer y > 0, a diagonal B with every entry ≥ 0 is raised
  entry by entry, with 0^y = 0: `[[0 0] [0 4]] 3/2 power` is
  [[0 0] [0 8]], as `0 3/2 power` is 0. The value needs no logarithm,
  and being diagonal is read from the entries without a tolerance.
  Keeping `log_undefined` for every base with a 0 eigenvalue was set
  aside: a scalar 0 would work while a diagonal with a 0 would not.

- **L81. In infix, parentheses mark a call and only a call.** A
  function is called with parentheses even with no arguments (`g()`),
  and a name never takes them (`pi`, not `pi()`). So the text shows
  what runs code and what reads a value. Allowing a bare call of a
  function with no arguments was set aside: it gives two ways to write
  one thing (R2).

- **L82. In infix `/` is always division, after `~` too.** Infix
  `~1/3` is `~1 3 divide`; fraction literals exist only in RPN and in
  matrix literals. The value is the same as the RPN literal `~1/3`,
  because a division of doubles is rounded to the nearest. Reading a
  whole fraction after `~` was set aside: an exception to a rule that
  has none.

- **L83. Parentheses make an expression.** A call in parentheses must
  leave one value, even on its own: `(lu(a))` is `stack_effect`.
  Treating parentheses around a lone call as transparent was set
  aside: a call of several values is written without them, and one
  rule (parentheses group a value) is enough.

- **L84. An infix span points to what is written.** A count of names
  that does not match points to `var` or `=`; a `variable` added by
  the translation for a function parameter or a `for` index points to
  that name in the text. Pointing to the keyword of the statement
  (`function`, `for`) was set aside: each added word comes from one
  written name, and that name is the more precise place.

- **L85. The reserved words are reserved in both notations.** The
  keywords of infix cannot be defined as names in RPN either, so a
  name defined in one notation can be used from the other in a
  session. They are listed once, with the rules of names. Reserving
  them only in infix was set aside: an RPN name such as `end` could
  never be read from an infix part.

- **L86. A count is read by its value.** Any exact literal whose
  value is a positive integer is a count: `2`, `2.0`, `4/2`, `[[2]]`.
  Accepting only digits was set aside: it adds a lexical rule for one
  case, while every other literal is read by its value.

- **L87. `vector` takes scalars.** An entry of `vector` that is not a
  scalar is `type_mismatch`. Stacking matrices as rows was set aside:
  `append_rows` already does it.

- **L88. Only a variable can be assigned.** `assign` on a name that
  does not exist is `unknown_word`; on any existing name that is not a
  variable, vocabulary and reserved words included, it is
  `not_assignable`. Calling a vocabulary word unknown was set aside:
  the name exists.

- **L89. Bindings are checked in the order of the declarations, as
  exact texts.** Each declaration in order (missing, invalid, digits),
  then the values with no declaration. A value is exactly a value
  text, without trimming: it is what an engine writes (E13), and a
  host that reads text from a person trims it itself. Trimming was set
  aside: it makes a second valid form of every value.

- **L90. A session is one program for its limits; a part is whole
  for its counts.** `maxSourceLength` bounds the sum of the parts, as
  steps count the whole session; measuring each part alone was set
  aside, since splitting a program would escape the limit. A count is
  written in the same part as its word: a value an earlier part
  already left on the stack is never read again as a count.

- **L91. `exact` drops the boolean mark.** `true exact` is 1: only
  the words that move or store a value keep the mark, and that list
  stays closed. Keeping the mark because `exact` changes nothing on an
  exact value was set aside: it adds an exception for a use no program
  needs.

- **L92. `Program.rpn` has one rule for whitespace in both
  notations.** For an RPN program, as for the translation of an infix
  one, each run of whitespace inside a literal becomes one space:
  `[[1   2]` and `[3 4]]` on two lines give `[[1 2] [3 4]]`, so the text
  always fits on one line. Copying literals as written was set aside,
  since the same value would print in two ways; rewriting each literal
  as the text of its value was set aside too, since it drops the form
  the author chose.

- **L93. A `syntax_error` points to one token.** The span is the first
  token that cannot stand where it is, whole: `2x`, the first `{` of a
  misplaced program, a misplaced `:x`, the `√` of `√9`; a statement or
  a text that ends too soon gives length 0 where it ends. Spanning the
  whole construct that fails was set aside, since it would need a rule
  for where each construct starts and ends; leaving the span free was
  set aside, since engines would differ.

- **L94. The lexical edges are closed by the rule they already
  follow.** What is written wrong is `syntax_error`; what has the form
  of a name and does not exist is `unknown_word`. So `{1}`, `[[1 2]]x`,
  `[1,,2]`, `[1,2,]`, `[[1 2] 3]` and `:π` are `syntax_error`; `-pi` is
  `unknown_word`, since a token starts as a number only with a digit,
  `.` or `[`, alone or after a sign or `~`. `#` starts a comment even
  right after a token. Carriage return is whitespace and a line ends at
  a line feed, so a text with CR LF reads the same.

- **L95. Only a visible name can clash.** A function, like a variable,
  lives until the end of its scope, and defining a name is
  `name_exists` only when a function or variable of that name is
  visible there: defined earlier in the text, in the same scope or an
  enclosing one. `true { { 1 } :g fn } if { 2 } :g fn g` gives `[2]`.
  Making function names unique in the whole program was set aside: it
  is an exception to the lexical scope that already holds for
  variables.

- **L96. No negative zero.** Every −0.0 in an approximate value, from a
  word or a literal, is +0.0. So the text of every approximate value
  reads back as the same doubles, and a word that depends on the sign
  of a zero, such as the angle of `natural_logarithm`, gives the same
  result in every engine. Writing −0.0 without its sign only in the
  text was set aside, since the value would still differ inside a run;
  reading `~-0.0` as −0.0 was set aside, since it makes an exception to
  `~` approximating the exact value.

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
| `{ A } { E } try`, with the error id pushed for `E` to take with `:e var` | `{ A } :id { E } try` (L33) | A variable cannot hold a name (L15), no word compares names, and infix cannot write `:id`; naming the error caught is explicit. |
| Three types on the stack: matrix, program, name | One value type, programs and names written in place (L8) | Moving programs and names on the stack let `prepare` lose track of which program runs (`swap ifelse`), with no use that needed it. |
| Two kinds of scope, the program and each call | Three, with each run of a control body (L53) | Otherwise `for` redefines its index each turn, and a `var` inside `if` exists or not depending on the condition. |

## Impact on the engine contract

Applied in `engine-api-contract.md` 0.2: `parameter` (L29) settles Q2,
sessions (L30) settle Q5, a tolerance (L57, L58) settles Q3, one value
type (L8), and every name and arity checked in `prepare` (L10, L28).
