# The calculatrix language

Language version: **0.1** (draft).

This document defines the calculatrix language: what a program is, what
it means, and which words it has. It is complete on its own: an engine
in any host language can be built from it, from
`calculatrix_mathematics.md`, which defines what each mathematical word
computes, and from `engine-api-contract.md`, which defines how a host
calls an engine. No implementation is normative.

Why each rule is as it is, and what was rejected, is recorded in
`language-decisions.md`.

## Changes

| Version | Date | Changes |
|---|---|---|
| 0.1 | 2026-11-02 | First version. |

A change to the syntax, to the meaning of a program, to the vocabulary,
to an error id or to the translation of infix into RPN is a new language
version.

## 1. Principles

- **One language, two notations.** RPN is the complete language. Infix is
  a way of writing it: an infix program means exactly the RPN program it
  translates to (section 9).
- **One reading.** Every valid text has exactly one reading. Where a
  short form could be read two ways, the explicit form is required and
  the short one is an error that names it.
- **Checked before running.** Every name and the stack effect of every
  word are known from the text, so `prepare` finds those errors before
  anything runs (section 10).
- **Exact unless marked.** Numbers are exact rationals. A value becomes
  approximate only when the program asks for it or an operation has no
  exact result, and it is marked as such.
- **Nothing silent.** A limit, a domain problem or a loss of exactness
  the program did not ask for is an error with an id.

## 2. Lexical structure

A program is a text in UTF-8.

**Tokens.** In RPN, tokens are separated by whitespace (spaces, tabs,
newlines); a newline is whitespace like any other. `{` and `}` are
tokens and are separated from their neighbours by whitespace like any
other token. A matrix literal is one token even when it contains
whitespace.

**Comments.** `#` outside a matrix literal starts a comment that runs to
the end of the line, in both notations.

**Case.** Names are case-sensitive: `A` and `a` are two names. Every word
of the vocabulary is lowercase, so `PI` is `unknown_word`.

**Numbers** are exact rationals:

    number   = [ "+" | "-" ] ( digits [ "." { digit } ] | "." digits )
               [ ( "e" | "E" ) [ "+" | "-" ] digits ]
    fraction = [ "-" ] digits "/" digits

`3`, `-2`, `0.1` (1/10), `.5`, `5.`, `1e-3` (1/1000), `1E400` (10^400).
A fraction `p/q` is one literal in RPN and inside matrix literals:
`1/3`, `-5/3`; `p/0` is `non_finite`; `1.5/2`, `1/2/3` and `1/-2` are
not literals. In infix a number has no sign (section 9.2) and `/` is
always division, so `1/3` has the same value in both notations.
`0x10`, `1_000`, `1e`, `NaN` and `Infinity` are not numbers.

**Approximate mark.** `~` in front of a literal, before its sign, makes
it approximate: `~0.1`, `~-0.1`, `~1/3`, `~[[1 2]]`. The mark belongs to
the literal: `-~0.1` is `syntax_error`. A marked literal outside the
range of a double is `non_finite`.

**Matrix literals.**

- Rows in brackets inside brackets: `[[1 2] [3 4]]`. A flat list is one
  row: `[1 2 3]` is 1×3.
- Entries are separated by whitespace, commas or both, and rows may
  touch: `[[0 -1][1 0]]`, `[[1,2],[3,4]]`.
- A sign or `~` in front applies to the whole matrix: `-[[1 2]]`. One
  `~` on any entry makes the whole matrix approximate.
- Entries are numbers or fractions only: no names, no expressions, no
  nesting deeper than two levels. A matrix holding variables is built
  with words (`vector`, `append_columns`, `append_rows`).
- `[]` and ragged rows are `dimension_mismatch`; unbalanced brackets are
  `syntax_error`.

**Name literals.** `:` followed by a name: `:x`, `:vat_rate`.

**Names.** A user name is a letter followed by letters, digits and `_`,
in ASCII: `a`, `A2`, `vat_rate`. Words join with `_`, never `-`, since
`-` is subtraction in infix. A user name cannot be a word of the
vocabulary (section 4.4).

## 3. Values

The stack holds one type of value, the matrix. Programs and names are
written in place, as arguments of the words that take them:

| Form | Literal | Written just before |
|---|---|---|
| matrix | `[[1 2] [3 4]]`, `5`, `1/3` | A value; a scalar is a 1×1 matrix. |
| program | `{ x x * }` | `function`, `if`, `ifelse`, `while`, `for`, `try`. It sees the names of the place where it is written. |
| name | `:x` | `variable`, `assign`, `function`, `parameter`, `try`. |

A `{ }` or a `:x` anywhere else is `syntax_error`: `true { 1 } { 2 }
swap ifelse` and `:x 5 swap var` have no meaning. A program or a name
is written right before its word, after the word's other written
arguments: `c { A } { B } ifelse`, `x :n var`, `{ A } :id { E } try`.

**Matrices** are exact or approximate as a whole. An exact entry is a
rational of any size; an approximate entry is a finite IEEE 754 double.
A complex number a + bi is the 2×2 matrix `[[a -b] [b a]]`, and the
constant `i` is `[[0 -1] [1 0]]`. What makes a result exact, and what
each mathematical word computes, is defined in
`calculatrix_mathematics.md`.

**Booleans** are the matrices `[1]` and `[0]` carrying a boolean mark,
written `true` and `false`.

- Comparisons, `and`, `or`, `not`, `true` and `false` produce marked
  booleans.
- Words that move or store a value without computing keep the mark:
  stack words, `variable`, `assign`, and reading a variable.
- Every other word drops it: `true true +` is `2`, `true transpose` is
  `[[1]]`.
- The mark does not affect equality: `true 1 ==` is `true`.
- Every word that takes a condition (`if`, `ifelse`, `while`, `and`,
  `or`, `not`) accepts only a marked boolean; anything else is
  `not_boolean`.

**Text.** Every value has one text that, read as a literal, gives the
value back:

- an exact scalar is an integer or a fraction in lowest terms with the
  sign on the numerator: `-7`, `1/3`;
- a matrix is its rows: `[[1 2] [3 4]]`;
- an approximate value carries `~` once in front of it;
- a boolean is `true` or `false`;

How a host formats a value for display (decimals, significant digits)
is the host's choice; the text above is what engines compare.

## 4. RPN

### 4.1 Running a program

A program is a sequence of tokens run from left to right against a
stack. Level 1 is the top of the stack. Each token is:

1. a number or matrix literal, which is pushed;
2. a word of the vocabulary, by its name or an alias, which runs;
3. a user name in scope: a variable or parameter pushes its value, a
   function runs;
4. anything else, which is `unknown_word`; a token that starts as a
   number or a matrix literal but is malformed is `syntax_error`.

A program `{ ... }` or a name `:x` belongs to the word written after
it; a program runs when that word runs it.

**Result.** The result of a program is the whole final stack, level 1
on top. An empty stack is a valid result.

### 4.2 Names and scope

Three words create or change names, and each takes the name from a
`:name` literal written in the program; names are never computed.

| Word | Alias | Effect | Meaning |
|---|---|---|---|
| `variable` | `var` | `x :n →` | Defines the variable `n` with the matrix `x`. |
| `assign` | `=` | `x :n →` | Gives the existing variable `n` the matrix `x`. |
| `function` | `fn` | `{ p } :n →` | Binds the program `p` to the name `n`. |

- **Variables hold matrices.** Programs get names only through
  `function`.
- **Lexical scope.** A name is visible from its definition to the end of
  its scope. There are three kinds of scope: the program, each call of
  a function, and each run of a program by a control word (section
  4.5). A program sees the names of the place where it is
  written, wherever it runs (a closure), and sees their current values:
  closures capture variables, not copies.
- **Lifetime.** A variable lives until the end of its scope; since a
  program never leaves the place where it is written, nothing outlives
  its scope. Before its definition it
  does not exist: `x 1 :x var` is `unknown_word`.
- **Every variable has a value.** `variable` always takes one, so a
  variable cannot be read before it is set.
- **No shadowing, no redefinition.** Defining a name that already exists
  is `name_exists`: a word of the vocabulary, a function, a parameter,
  or a variable of the same scope or of an enclosing one.
- **Assignment** changes a variable only. `assign` on a name never
  defined is `unknown_word`; on a parameter, a function or a constant it
  is `not_assignable`.
- **Same level as constants.** A user name is used as a bare word, like
  `pi`.

```
1 :a var
a 1 + :a assign
a                                       # 2
```

### 4.3 Functions

A function is a program bound to a name. Its arguments come from the
stack:

```
{ :x var  x x * 1 + } :f function       # f(x) = x^2 + 1
3 f                                     # 10
```

- **Inputs.** A function takes as many values as the `:name var` that
  open its body. `var` takes the value on top of the stack, so the
  arguments are named last to first:

  ```
  { :y var :x var  x y - } :minus function
  5 3 minus                             # 2
  ```

  Inside the body nothing reaches below those values: `{ dup * } :sq
  function` takes no values, so its `dup` is `stack_effect`.
- **Outputs.** What a function leaves is deduced from the stack effects
  of the words in its body.
- **Recursion.** The name of a function is visible inside its own
  body, so a function can call itself. No other name is visible before
  its definition: in `{ g } :f function { f } :g function` the `g`
  inside `f` is `unknown_word`, so there is no mutual recursion.
- **Calls.** Each call gets a fresh scope, so recursion works. The body
  sees the names of the place where the function is written, never the
  caller's variables.

  ```
  { :n var  n 1 <= { 1 } { n n 1 - fact * } ifelse } :fact function
  3 fact                                # 6
  ```

  In a recursive function the branch that does not recurse fixes the
  effect, and the recursive branch is checked against it. A function
  with no such branch has no effect to fix, and is `stack_effect`.

### 4.4 Stack effects

Every word has one stack effect, known before running: how many values
it takes and how many it leaves. `prepare` follows them through the
whole program (section 10).

- A count is a literal written just before its word: `1 2 3 3 vector`,
  `3 pick`. A computed count (`n vector`) is `stack_effect`.
- No program between `{ }` takes values from below the point where it
  starts, as a function takes none below its arguments. Only the body
  of `for` takes one value, its index. So the effect of a body is how
  many values it leaves:
  - the bodies of `if`, `while` and `for` leave none;
  - the condition of `while` leaves one boolean;
  - the two branches of `ifelse` leave the same number, and so do the
    two programs of `try`.

  `5 true { 1 + } if` and `0 1 10 { + } for` are `stack_effect`; a
  body accumulates through a variable: `s k + :s assign`.
- A count is a literal of a positive integer (`0 pick` and
  `2.5 vector` are `type_mismatch`, found by `prepare`). Only the
  counts of `vector`, `pick` and `roll` decide a stack effect; the
  sizes of `zeros` or `identity` may be computed (`n identity`).

### 4.5 Control

| Word | Effect | Meaning |
|---|---|---|
| `if` | `c { A } →` | Runs `A` when `c` is `true`. |
| `ifelse` | `c { A } { B } →` | Runs `A` when `c` is `true`, `B` otherwise. |
| `while` | `{ C } { A } →` | Runs `C`, which leaves a boolean; while it is `true`, runs `A` and repeats. |
| `for` | `a b { A } →` | Runs `A` for each integer k from `a` to `b`, both included, with k on top of the stack. When `a` is greater than `b` it runs `A` zero times. |
| `try` | `{ A } :id { E } →` | Runs `A`. If `A` fails with the error `id`, the stack returns to what it was before `A` and `E` runs. Any other error goes on. |

```
0 :s var
1 10 { :k var  s k + :s assign } for
s                                       # 55

{ a inverse } :singular_matrix { a size zeros } try
```

- Each time a control word runs one of its programs, that run has its
  own scope: what it defines with `var` (the index of `for` included)
  ends with the run, and the names outside it
  are visible and can be assigned. So after `c { 1 :x var } if`, `x`
  does not exist, whatever `c` was.
- In `for`, `a` and `b` are integer scalars; anything else is
  `type_mismatch`.
- In `try`, the id is a name literal of a run error (section 8):
  `:singular_matrix`. There is no way to catch any error: two ids take
  two nested `try`. A name that is no run error is `unknown_word`.
  `limit_*` errors and errors of `prepare` and of binding are never
  caught. What `A` assigned before failing stays assigned; only the
  stack is restored.

### 4.6 Parameters

A program declares each value it receives from its host:

```
:price parameter
price 21 percent                        # the VAT of price
```

- A parameter holds a matrix, is used as a bare word, and is visible
  from its declaration on. It cannot be assigned.
- Parameters are declared at the top level of the program, outside any
  function or control body (`parameter_in_function`).
- A value given by the host is the text of a matrix literal; anything
  else (`true`, `{ 1 }`, `1/0`) is `binding_invalid`.
- Before running, the values the host gives are checked against the
  declarations: a missing value is `binding_missing`, a value with no
  declaration is `binding_unknown`, and a text that is not a value
  literal is `binding_invalid`. Values reach the program only this way,
  never by splicing text into it.

### 4.7 Sessions

A session is one program written in parts. The blocks of a document and
the lines of a calculator are appended to one program: variables,
functions and the stack carry on, and every rule above applies
unchanged. Each part has its own notation: an infix part is appended
as its translation, so a document may mix RPN and infix blocks.

- Running a block of a document runs the document from its start up to
  that block, and the block shows the stack as it is after it.
- In a calculator, each line is appended. `var` on an existing name is
  `name_exists`; `assign` changes it. A line that fails is not
  appended: the session stays as it was before it.
- Limits count per run. Running a block of a document counts the whole
  document up to it.
- Nothing persists between sessions.

## 5. Vocabulary

Each word has one name and may have aliases. A name is written out,
never abbreviated; short forms and symbols are aliases. Names and
aliases are all different from each other.

Effects read `inputs → outputs`, the rightmost input on top. `A`, `B`,
`X` are matrices, `k` and `n` scalars, `b` a boolean; `{ A }` and `:n`
are written in place, not taken from the stack. What each
mathematical word computes, its preconditions and its errors are in
`calculatrix_mathematics.md`; indices are 1-based.

### 5.1 Language

| Name | Aliases | Effect |
|---|---|---|
| `variable` | `var` | `x :n →` |
| `assign` | `=` | `x :n →` |
| `function` | `fn` | `{ p } :n →` |
| `parameter` | | `:n →` |
| `if` | | `b { A } →` |
| `ifelse` | | `b { A } { B } →` |
| `while` | | `{ C } { A } →` |
| `for` | | `a b { A } →` |
| `try` | | `{ A } :id { E } →` |

### 5.2 Booleans and comparisons

| Name | Aliases | Effect | Meaning |
|---|---|---|---|
| `true` | | `→ b` | |
| `false` | | `→ b` | |
| `and` | | `b b → b` | |
| `or` | | `b b → b` | |
| `not` | | `b → b` | |
| `equal` | `==` | `A B → b` | Same shape and every entry equal. |
| `not_equal` | `!=` | `A B → b` | `equal` negated. |
| `less` | `<` | `A B → b` | |
| `less_equal` | `<=` | `A B → b` | |
| `greater` | `>` | `A B → b` | |
| `greater_equal` | `>=` | `A B → b` | |

- `equal` and `not_equal` take exact values only; an approximate
  operand is `approximate_equality`. To compare approximations, compare
  their difference: `abs(x - y) < 1e-10`.
- `less`, `less_equal`, `greater` and `greater_equal` take real
  scalars: a matrix λI of any size, 1×1 included, compares as λ
  (`[[2 0] [0 2]] 3 <` is `true`, `i i * 0 <` is `true`). λI is
  recognized only when every entry off the diagonal is exactly 0. Any
  other matrix, a complex value included, is `not_ordered`.

### 5.3 Arithmetic

| Name | Aliases | Effect |
|---|---|---|
| `add` | `+` | `A B → A+B` |
| `subtract` | `-` | `A B → A−B` |
| `multiply` | `*` | `A B → AB` |
| `divide` | `/` | `A k → A/k` |
| `negate` | `neg` | `A → −A` |
| `power` | `pwr`, `^` | `B Y → B^Y` |
| `square_root` | `sqrt`, `√` | `X → X^(1/2)` |
| `inverse` | `inv` | `A → A^−1` |
| `exponential` | `exp` | `X → e^X` |
| `natural_logarithm` | `ln` | `X → log X` |
| `percent` | | `A k → A·k/100` |
| `absolute_value` | `abs` | `k → |k|` |
| `approximate` | `approx`, `num` | `A → ~A` |
| `exact` | | `~A → A` |

- `percent`: `200 15 percent` is `30`. `%` is not a word in either
  notation; it is `syntax_error`, and the message says to write
  `percent`.
- `absolute_value` takes a real scalar (λI, as `less`) and leaves |λ|
  as 1×1. Any other matrix is `not_ordered`, and the message suggests
  `frobenius_norm`.

### 5.4 Stack

| Name | Aliases | Effect |
|---|---|---|
| `drop` | | `A →` |
| `duplicate` | `dup` | `A → A A` |
| `over` | | `A B → A B A` |
| `swap` | | `A B → B A` |
| `rotate` | `rot` | `A B C → B C A` |
| `pick` | | `… n → …` (level n copied to the top) |
| `roll` | | `… n → …` (level n moved to the top) |

Stack words move matrices, keeping their exactness and boolean mark.

### 5.5 Construction and access

| Name | Effect |
|---|---|
| `vector` | `x1 … xn n → [[x1] … [xn]]` |
| `zeros` | `r c → r×c zeros` |
| `ones` | `r c → r×c ones` |
| `identity` | `n → n×n identity` |
| `size` | `A → r c` |
| `row` | `A i → row i` (1×c) |
| `column` | `A j → column j` (r×1) |
| `entry` | `A i j → a_ij` |

### 5.6 Structure

| Name | Effect |
|---|---|
| `transpose` | `A → Aᵀ` |
| `append_rows` | `A B → A over B` |
| `append_columns` | `A B → [A B]` |
| `delete_row` | `A i → A` without row i |
| `delete_column` | `A j → A` without column j |
| `duplicate_row` | `A i → A` with row i repeated after it |
| `duplicate_column` | `A j → A` with column j repeated after it |
| `move_row` | `A i k → A` with row i moved to position k |
| `move_column` | `A j k → A` with column j moved to position k |

### 5.7 Linear algebra

| Name | Aliases | Effect |
|---|---|---|
| `determinant` | `det` | `A → det A` |
| `trace` | | `A → tr A` |
| `rank` | | `A → rank A` |
| `frobenius_norm` | `norm` | `A → ‖A‖_F` |
| `spectral_norm` | | `A → ‖A‖_2` |
| `eigenvalues` | `eig` | `A → column of eigenvalues, descending` |
| `diagonalize` | | `A → P D` (A = P D P^−1) |
| `cofactors` | | `A → cofactor matrix` |
| `adjugate` | `adj` | `A → adj A` |
| `dot` | | `A B → A·B` |
| `cross` | | `A B → A×B` |
| `reduced_row_echelon_form` | `rref` | `A → rref A` |
| `lu` | | `A → P L U` (PA = LU) |
| `qr` | | `A → Q R` (A = QR) |

### 5.8 Constants

| Name | Aliases | Effect | Value |
|---|---|---|---|
| `pi` | `π` | `→ pi` | the double nearest to π, approximate |
| `e` | | `→ e` | the double nearest to e, approximate |
| `i` | | `→ i` | `[[0 -1] [1 0]]`, exact |

A constant is a name, not a number: `2e` and `e3` are not words, `1e3`
is the number 1000, and `-pi` is written `pi negate`.

## 6. Steps

Every run counts steps, so a step limit stops at the same point on every
engine:

- pushing a literal (`3`, `[[1 2]]`): 1; a program or a name written
  in place is part of its word and counts nothing;
- running a word of the vocabulary: 1, whatever work it does;
- pushing a variable or parameter: 1;
- calling a function: 1, plus the steps of its body;
- a control word: 1, plus the steps of every program it runs, every turn
  of a loop included. The index that `for` pushes is not written, so it
  counts nothing.

A word that fails counts its step.

Infix counts on its translation: `a + b` is 3 steps.

## 7. Limits

A run has limits on digits of exact numbers, steps, stack depth, source
length and call depth. Their defaults and maxima are part of the engine
contract. Going over one is an error of phase `limit`
(`limit_digits`, `limit_steps`, `limit_stack`, `limit_source`,
`limit_calls`), which no `try` catches. The call depth counts calls of
functions only, not runs of control bodies.

## 8. Errors

Every error has an id. The id is the contract; the message is for
people and may change. Each id belongs to one phase:

- **prepare**: found in the text, before anything runs;
- **binding**: the host's values against the declared parameters;
- **run**: while running;
- **limit**: a limit of the run.

| Phase | Id | Raised for |
|---|---|---|
| prepare | `syntax_error` | malformed text; in infix also `2x`, `%`, `:` outside `for`, `a < b < c`, `√9` |
| prepare | `unknown_word` | a token that is no literal, no word and no name in scope |
| prepare | `name_exists` | defining a name that already exists |
| prepare | `not_assignable` | `assign` on a parameter, a function or a constant |
| prepare | `stack_effect` | an effect that does not hold: branches that differ, a function reaching below its arguments, a body that does not leave the stack as it found it, a call leaving several values inside an infix expression, a count of names that does not match, a count that is not a literal |
| prepare | `stack_underflow` | a word with fewer values below it than it takes |
| prepare | `parameter_in_function` | `parameter` inside a function |
| prepare | `unsupported_feature` | a feature of a newer language version than the engine's |
| binding | `binding_missing` | a declared parameter with no value |
| binding | `binding_unknown` | a value with no declared parameter |
| binding | `binding_invalid` | a value text that is not a value literal |
| run | `type_mismatch` | an operand of the wrong kind: a non-integer or non-positive index, a non-scalar divisor, a non-integer bound of `for` |
| run | `not_boolean` | a condition, `and`, `or` or `not` on a value that is not a marked boolean |
| run | `not_ordered` | a comparison or `absolute_value` on a value that is not a real scalar |
| run | `approximate_equality` | `equal` or `not_equal` with an approximate operand |
| run | `dimension_mismatch` | incompatible or impossible shapes, an index out of range |
| run | `singular_matrix` | inverting a singular matrix |
| run | `rank_deficient` | `qr` on a matrix without full column rank |
| run | `non_finite` | a result or literal that is not a finite number |
| run | `log_undefined` | a logarithm, square root or fractional power with no principal value |
| run | `ambiguous_power` | a power of matrices whose logarithm branch is not determined |
| run | `complex_result` | a real word whose result would be complex |
| run | `not_diagonalizable` | `diagonalize`, or a word built on it, on a defective matrix |
| limit | `limit_digits`, `limit_steps`, `limit_stack`, `limit_source`, `limit_calls` | a limit of the run |

Since every word has a known effect, `prepare` follows the depth of the
stack through the whole program, from the stack the program starts
with (empty, or the session's), and reports `stack_underflow` there.

Every error in a literal is found by `prepare`, with the id of its
cause: `1.5/2` and `0x10` are `syntax_error`, `[]` is
`dimension_mismatch`, `1/0` and `~1e400` are `non_finite`. So no `try`
catches them.

A run reports one error: the first phase that fails (prepare, binding,
run, limit), and within `prepare` the error that comes first in the
text.

## 9. Infix

### 9.1 Statements

A program is a sequence of statements, separated by newlines or by `;`.
A statement continues on the next line while a parenthesis or a bracket
is open. Blocks close with `end`.

| Statement | Translation |
|---|---|
| `var x = e` | `T(e) :x variable` |
| `var x, y, z = f(a)` | `T(f(a)) :z variable :y variable :x variable` |
| `x = e` | `T(e) :x assign` |
| `x, y = f(a)` | `T(f(a)) :y assign :x assign` |
| `parameter p` | `:p parameter` |
| `function f(x, y) S end` | `{ :y variable :x variable T(S) } :f function` |
| `if c S end` | `T(c) { T(S) } if` |
| `if c S else R end` | `T(c) { T(S) } { T(R) } ifelse` |
| `while c S end` | `{ T(c) } { T(S) } while` |
| `for k in a:b S end` | `T(a) T(b) { :k variable T(S) } for` |
| `try S catch id R end` | `{ T(S) } :id { T(R) } try` |
| `e` | `T(e)` |

- After `catch` comes the id of an error, not a variable: its place in
  the grammar says so, with no `:`.
- An expression on its own is a statement and leaves its value on the
  stack. A call on its own may leave several values (`lu(a)` leaves
  three); only inside an expression must it leave one.
- The condition of `if` and `while`, and the range of `for`, end at the
  end of their line or at `;`: `if a - b` then the body on the next
  line, or `if a; -b; end` on one.
- `if`, `else`, `end`, `while`, `for`, `in`, `try`, `catch`,
  `function`, `var` and `parameter` are reserved: defining one as a
  name is `name_exists`.
- With several names before `=`, the names read in the order the word
  leaves its values, and their count must match what it leaves
  (`stack_effect` otherwise).
- A range `a:b` exists only after `for ... in`; it is not a value, and
  `:` anywhere else is `syntax_error`. It includes its end; `1:0` is
  empty. There is no step.
- `function` takes no `parameter` in its body.

### 9.2 Expressions

From the tightest to the loosest:

| Level | Operators | Associativity | Translation |
|---|---|---|---|
| 1 | calls `f(x, y)`, `( )` | | `T(x) T(y) f` |
| 2 | `^` | right | `T(x) T(y) power` |
| 3 | unary `-` | | `T(x) negate` |
| 4 | `*` `/` | left | `multiply`, `divide` |
| 5 | `+` `-` | left | `add`, `subtract` |
| 6 | `==` `!=` `<` `<=` `>` `>=` | none | `equal`, `not_equal`, `less`, `less_equal`, `greater`, `greater_equal` |
| 7 | `not` | | `T(x) not` |
| 8 | `and` | left | `T(x) T(y) and` |
| 9 | `or` | left | `T(x) T(y) or` |

- `2^3^2` is `2^9`; `-2^2` is `-4`; `a/b*c` is `(a/b)*c`.
- The exponent of `^` may start with `-`, which negates the whole power
  on its right: `2^-2` is `2 2 negate power`, and `2^-2^2` is
  `2^-(2^2)`, `2 2 2 power negate power`.
- Comparisons do not chain: `a < b < c` is `syntax_error`.
- A number has no sign: `-2` is `2 negate`, `3*-2` is
  `3 2 negate multiply`, `-[[1 2]]` is `[[1 2]] negate`. Signs inside
  a matrix literal belong to it (`[[1 -2]]`), and `~` keeps its sign
  after it (`~-0.1`).
- Multiplication is always written: `2x` is `syntax_error` and the
  message says `write 2*x`.
- Every word is called with parentheses, by its name or an alias:
  `sqrt(x)`, `√(x)`, `square_root(x)`. `√9` is `syntax_error` and the
  message says `write √(9)`.
- A call inside an expression must leave exactly one value: `x + lu(a)`
  is `stack_effect`, and the message suggests `var p, l, u = lu(a)`.
- `vector(x, y, z)` translates to `T(x) T(y) T(z) 3 vector`: the
  translation adds the number of arguments.
- Names (variables, parameters, constants, `true`, `false`) are bare
  words: `pi`, `price`.
- Matrix literals hold numbers only, as in RPN.

### 9.3 Translation

Every engine translates the same infix program to the same RPN text,
byte for byte:

- Each subexpression translates on its own, with no optimization:
  `inv(a*a)` is `a a multiply inverse`, never `a duplicate multiply
  inverse`.
- Every word is written by its name, never an alias.
- A literal is copied as written, each run of whitespace inside it
  replaced by one space.
- Tokens are separated by one space, `{` and `}` included, and
  statements too; the result is one line. Comments are dropped.

```
var s = 0
for k in 1:10
  s = s + k
end
s
```

translates to

```
0 :s variable 1 10 { :k variable s k add :s assign } for s
```

## 10. Prepare and run

A program is checked before it runs. The host says which notation a
text is written in, RPN or infix; the text itself never says it.
`prepare` reads the whole text and reports, with no code run:

- syntax errors, and in infix the translation;
- every name: defined before use, never redefined, assigned only when
  it is a variable;
- the stack effect of every function, branch and loop body, and the
  depth of the stack through the program.

`run` then checks the host's values against the declared parameters and
runs the program, counting steps.

## 11. Examples

Each example gives infix, its RPN translation, and the stack left.

**A function.**

```
function f(x)
  x^2 + 1
end
f(3)
```

```
{ :x variable x 2 power 1 add } :f function 3 f
```

`1: 10`

**Recursion.**

```
function fact(n)
  if n <= 1
    1
  else
    n * fact(n - 1)
  end
end
fact(5)
```

```
{ :n variable n 1 less_equal { 1 } { n n 1 subtract fact multiply } ifelse } :fact function 5 fact
```

`1: 120`

**Inverse by the adjugate.**

```
var a = [[1 2] [3 4]]
var b = (1/det(a))*adj(a)
a*b
```

```
[[1 2] [3 4]] :a variable 1 a determinant divide a adjugate multiply :b variable a b multiply
```

`1: [[1 0] [0 1]]`

**Several results.**

```
var a = [[4 3] [6 3]]
var p, l, u = lu(a)
p*a == l*u
```

```
[[4 3] [6 3]] :a variable a lu :u variable :l variable :p variable p a multiply l u multiply equal
```

`1: true`

**A parameter and percent.**

```
parameter price
price + percent(price, 21)
```

```
:price parameter price price 21 percent add
```

With `price` bound to `200`: `1: 242`.

**Catching an error.**

```
var a = [[1 2] [2 4]]
try
  inv(a)
catch singular_matrix
  var r, c = size(a)
  zeros(r, c)
end
```

```
[[1 2] [2 4]] :a variable { a inverse } :singular_matrix { a size :c variable :r variable r c zeros } try
```

`1: [[0 0] [0 0]]`

## 12. Not in this version

- Element-wise operations (`.*`, `.==`).
- Expressions inside matrix literals.
- A step in ranges.
- `break`, `return`, `times`, `each`.
- The modulus of a complex number in `absolute_value`.
- Symbolic computation, and the canonical form of symbolic results.
- A program as a library whose functions a host calls by name; a host
  calls a function by appending a call to a session (section 4.7).
- The document format (Markdown with blocks and `{{ }}`), which has its
  own specification.
