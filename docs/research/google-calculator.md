# Google Calculator — Internal Logic and Architecture Reference

## Overview

Google Calculator is an interactive widget integrated into Google Search. It
appears when users search for math expressions or the word "calculator".
Unlike immediate-execution physical calculators, Google uses an expression-based
(formula) model and evaluates with standard operator precedence (PEMDAS/BODMAS).

It is a canonical declarative calculator: users describe what to compute, not
how to execute it step by step.

## Input Model: Infix Notation with Precedence

```
Input: 2 + 3 × 4
Result: 14 (NOT 20)

Reason: Multiplication has higher precedence than addition.
2 + (3 × 4) = 2 + 12 = 14
```

### Contrast with basic calculators (such as Casio HL-820LV)

| Aspect | Casio HL-820LV | Google Calculator |
|--------|----------------|-------------------|
| Model | Imperative (chain) | Declarative (formula) |
| Precedence | No, left-to-right | Yes, full PEMDAS |
| Parentheses | Not supported | Supported and nestable |
| Display | Result only | Full expression + result |
| Evaluation | On each operator | On `=` (or live preview updates) |

## Internal Architecture

### Evaluation Pipeline

```
┌──────────┐    ┌───────────┐    ┌──────────┐    ┌────────────┐    ┌──────────┐
│  Input   │───►│  Lexer /  │───►│  Parser  │───►│ Evaluator  │───►│  Output  │
│ (string) │    │ Tokenizer │    │  (AST)   │    │ (traverse) │    │ (number) │
└──────────┘    └───────────┘    └──────────┘    └────────────┘    └──────────┘
```

### Phase 1: Tokenization (Lexer)

The lexer converts input text into typed tokens.

#### Token types

```
NUMBER      → integers and decimals: 42, 3.14, .5, 0.001
OPERATOR    → +, -, ×, ÷, ^
UNARY_OP    → - (negation when found at expression start or after operator/paren)
FUNCTION    → sin, cos, tan, log, ln, sqrt, abs, etc.
LPAREN      → (
RPAREN      → )
COMMA       → ,
CONSTANT    → π, e
```

#### Tokenization example

```
Input: "2 + sin(3.14) × -4"

Tokens: [
  { type: NUMBER,   value: 2 },
  { type: OPERATOR, value: '+' },
  { type: FUNCTION, value: 'sin' },
  { type: LPAREN },
  { type: NUMBER,   value: 3.14 },
  { type: RPAREN },
  { type: OPERATOR, value: '×' },
  { type: UNARY_OP, value: '-' },
  { type: NUMBER,   value: 4 },
]
```

#### Lexer challenges

- Distinguish unary minus from binary subtraction
- Handle implicit multiplication: `2π`, `3(4+5)`
- Recognize function identifiers (`sin`, `cos`, `log`)

### Phase 2: Parsing — Shunting Yard Algorithm

Google-style calculators can use a Shunting Yard variant (Dijkstra, 1961) to
convert infix notation into either RPN or an AST.

#### Precedence table

| Precedence | Operators | Associativity |
|------------|-----------|---------------|
| 1 (lowest) | `+`, `-` | Left |
| 2 | `×`, `÷` | Left |
| 3 | unary `-` | Right |
| 4 | `^` | Right |
| 5 (highest) | functions | N/A |

#### Shunting Yard pseudocode

```
input: token list
output: output queue (RPN) or AST

operator_stack = []
output_queue = []

for each token:
    if token is NUMBER or CONSTANT:
        push token to output_queue

    if token is FUNCTION:
        push token to operator_stack

    if token is OPERATOR (o1):
        while top of stack is operator (o2)
              and o2 is not LPAREN
              and (o2 precedence > o1 precedence
                   or (same precedence and o1 is left-associative)):
            pop o2 to output_queue
        push o1 to operator_stack

    if token is LPAREN:
        push to operator_stack

    if token is RPAREN:
        while top is not LPAREN:
            pop to output_queue
        pop LPAREN
        if top is FUNCTION:
            pop FUNCTION to output_queue

while operator_stack not empty:
    pop to output_queue
```

### Phase 3: Evaluation

After conversion to RPN or AST, evaluation is straightforward.

#### RPN evaluation (stack-based)

```
evaluation_stack = []

for each token in RPN:
    if token is NUMBER:
        push token

    if token is BINARY_OPERATOR:
        right = pop()
        left = pop()
        push apply(operator, left, right)

    if token is UNARY_OPERATOR or FUNCTION:
        operand = pop()
        push apply(function, operand)

final_result = pop()
```

#### AST evaluation (tree walking)

```
function evaluate(node):
    if node is NumberLiteral:
        return node.value

    if node is BinaryExpression:
        left = evaluate(node.left)
        right = evaluate(node.right)
        return applyOp(node.operator, left, right)

    if node is UnaryExpression:
        operand = evaluate(node.operand)
        return applyUnary(node.operator, operand)

    if node is FunctionCall:
        arg = evaluate(node.argument)
        return applyFunction(node.name, arg)
```

### Alternative: Recursive Descent Parser

A common alternative is recursive descent, where each precedence level maps to
a parsing function.

Advantages:

- Excellent error locality
- Easy to extend with new operators/functions
- O(n) complexity for expression size
- No external parser generator required

## Google Calculator Functional Set

### Supported operators

| Operator | Symbol | Precedence |
|----------|--------|------------|
| Addition | `+` | 1 |
| Subtraction | `-` | 1 |
| Multiplication | `×` | 2 |
| Division | `÷` | 2 |
| Modulo | `mod` | 2 |
| Power | `^` | 3 (right-assoc) |
| Factorial | `!` | 4 (postfix) |

### Supported functions

| Function | Description |
|----------|-------------|
| `sin`, `cos`, `tan` | Trigonometric |
| `arcsin`, `arccos`, `arctan` | Inverse trigonometric |
| `ln` | Natural logarithm |
| `log` | Base-10 logarithm |
| `sqrt` (`√`) | Square root |
| `abs` | Absolute value |
| `exp` | e^x |

### Constants

| Constant | Value |
|----------|-------|
| `π` | 3.14159265358... |
| `e` | 2.71828182845... |

### Angle modes

- Radians (default)
- Degrees (UI toggle)

## Error Handling

### Parsing-detectable errors

| Error | Example | Message |
|-------|---------|---------|
| Missing closing parenthesis | `(2 + 3` | "Missing )" |
| Extra closing parenthesis | `2 + 3)` | "Unexpected )" |
| Consecutive operators | `2 + × 3` | "Unexpected operator" |
| Empty expression | ` ` | "No expression" |
| Function without argument | `sin()` | "Expected expression" |

### Evaluation-detectable errors

| Error | Example | Result |
|-------|---------|--------|
| Division by zero | `1 ÷ 0` | `Infinity` or error |
| Square root of negative | `√(-1)` | `NaN` or error |
| Overflow | `10^999` | `Infinity` |
| Invalid domain | `arcsin(2)` | `NaN` or error |

## UI State Model

```
State = {
    expression: string,
    displayValue: string,
    result: string | null,
    cursor: number,
    angleMode: 'rad' | 'deg',
    memory: number,
    history: Expression[],
    error: string | null
}
```

### Live preview

Google often shows a partial result while typing. This requires:

1. Tolerant parsing for incomplete expressions
2. Auto-closing missing parentheses in preview mode
3. Ignoring trailing operators for preview
4. Debouncing re-evaluation

## Numeric Precision

### IEEE 754 double precision

- ~15-17 significant digits
- Range: ±5.0 × 10^−324 to ±1.7976931348623157 × 10^308
- Known issue: `0.1 + 0.2` is not exactly `0.3`

### Mitigation strategies

1. Display rounding (10-12 significant digits)
2. Epsilon-based integer checks
3. Smart formatting (`0.30000000000000004` → `0.3`)

## Implications for Calculatrix

### What we adopt

1. Precedence-based evaluation (full PEMDAS)
2. Parentheses support
3. Tokenizer → Parser → Evaluator architecture
4. Recursive descent parser for maintainability
5. Live preview experience
6. Graceful error handling
7. IEEE 754 with smart display rounding

### What we do not adopt

1. Full scientific function set
2. Graphing features
3. Persistent history by default
4. Free text input in the Casio-style mode

### Resulting hybrid: Casio skin, Google brain

```
┌─────────────────────────────────────────────┐
│  UI/Layout: Casio HL-820LV                  │
│  • 4-column keypad                           │
│  • Minimal visual language                   │
│  • Familiar tactile button mapping           │
│                                             │
│  Internal engine: Google-style               │
│  • Build expression string                   │
│  • Tokenize → Parse → Evaluate              │
│  • Respect operator precedence               │
│  • Live result preview                       │
│  • Robust error handling                     │
└─────────────────────────────────────────────┘
```

## References

- Dijkstra, E. (1961). Algol 60 translation (Shunting Yard origins)
- Nystrom, R. Crafting Interpreters, chapter on expression parsing
- Wikipedia: Shunting Yard Algorithm
- Wikipedia: Calculator input methods
- Google support documentation for calculator capabilities
- IEEE 754-2019 floating-point standard
