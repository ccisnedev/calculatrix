# RPN — Reverse Polish Notation

## Summary

Research on Reverse Polish Notation (RPN), HP-50g stack behavior through RPL,
and modern implementation alternatives for Calculatrix Stage 2.

---

## 1. RPN fundamentals

### 1.1 Definition

RPN (Reverse Polish Notation) is a mathematical notation where operators come
after their operands, removing the need for parentheses and precedence rules.

| Infix | RPN |
|-------|-----|
| `3 + 4` | `3 4 +` |
| `(3 + 4) × 5` | `3 4 + 5 ×` |
| `3 + 4 × 5` | `3 4 5 × +` |
| `(1+2)×(3+4)` | `1 2 + 3 4 + ×` |

### 1.2 How the stack works

1. Read token from left to right
2. If token is a number, push it to stack
3. If token is an operator, pop operands, apply operation, push result

```
Input: 3 4 + 5 ×

Stack:  []
→ 3    [3]
→ 4    [3, 4]
→ +    [7]
→ 5    [7, 5]
→ ×    [35]
```

### 1.3 Advantages over infix notation

- No parentheses required
- Fewer keystrokes in many scenarios
- Fewer user mistakes in complex calculations
- Linear left-to-right evaluation
- Simple implementation with a stack model

### 1.4 Timeline

| Year | Milestone |
|------|-----------|
| 1924 | Jan Łukasiewicz introduces Polish notation (prefix) |
| 1941 | Konrad Zuse uses postfix in Z3-like workflows |
| 1957 | Charles Hamblin formalizes RPN |
| 1963 | Friden EC-130: first RPN calculator with 4-level stack |
| 1972 | HP-35: first portable scientific RPN calculator |
| 1986 | HP introduces RPL with dynamic stack |
| 2006 | HP 50g: final HP RPL flagship |
| 2013 | HP Prime: Advanced RPN with deep fixed stack |

---

## 2. Classic 4-level stack (HP-35 to HP-42S)

### 2.1 Architecture

```
┌─────┐
│  T  │
├─────┤
│  Z  │
├─────┤
│  Y  │
├─────┤
│  X  │  ← displayed result level
└─────┘
```

### 2.2 ENTER behavior

`ENTER` copies X to Y, pushing Y to Z and Z to T.
Previous T is dropped silently.

### 2.3 Special rules

- Automatic stack lift after entering numbers
- Temporary lift disable after `ENTER`
- T duplication on drop in some classic behaviors

### 2.4 Stack manipulation commands

| Command | Effect |
|---------|--------|
| `ENTER` | Duplicate X to Y and lift |
| `x↔y` | Swap X and Y |
| `R↓` | Rotate down |
| `R↑` | Rotate up |
| `LASTx` | Recall previous X |

### 2.5 Limitations

- Only four simultaneous values
- Silent overflow in deep workflows
- T-duplication can confuse new users

---

## 3. HP-50g RPL — dynamic stack

### 3.1 Architecture

HP-50g uses RPL (Reverse Polish Lisp), replacing fixed 4-level stack with a
dynamic stack bounded by available memory.

```
┌─────────┐
│ Level n │
├─────────┤
│   ...   │
├─────────┤
│ Level 3 │
├─────────┤
│ Level 2 │
├─────────┤
│ Level 1 │
└─────────┘
```

### 3.2 Key differences from classic RPN

| Aspect | Classic RPN | RPL (HP-50g) |
|--------|-------------|--------------|
| Stack size | 4 fixed levels | Dynamic (memory-limited) |
| Overflow | Silent value loss | Explicit memory error |
| Underflow | Duplication behavior | Explicit argument error |
| ENTER | Duplicate and lift | Separator, no forced duplication |
| Stack types | Mostly numeric | Typed objects (numbers, strings, lists, matrices, programs) |
| Programmability | Keystroke model | RPL language |

### 3.3 Common HP-50g stack ops

| Command | Description |
|---------|-------------|
| `DUP` | Duplicate top |
| `DROP` | Remove top |
| `SWAP` | Swap top two |
| `ROT` / `UNROT` | Rotate top 3 |
| `PICK` | Copy nth level to top |
| `OVER` | Copy second element to top |
| `DEPTH` | Push stack size |
| `CLEAR` | Clear stack |

### 3.4 RPL language model

RPL combines:

- RPN interaction model
- Forth-like concatenative programming
- Lisp-like list and symbolic handling

### 3.5 Typed stack objects

RPL stack can hold:

- Real and complex numbers
- Strings
- Lists
- Vectors and matrices
- Algebraic expressions
- Programs
- Symbols
- Unit-aware values

---

## 4. Modern RPN alternatives

### 4.1 Entry RPN

`ENTER` acts as a separator without implicit duplication.
Reduces confusion while keeping RPN flow.

### 4.2 Advanced RPN (HP Prime)

- Deep fixed stack (e.g., 128 levels)
- Entry RPN behavior
- Still less flexible than fully dynamic typed stack

### 4.3 Dynamic typed stacks (RPL / newRPL / DB48X)

- newRPL: modern open-source RPL implementation
- DB48X: RPL-inspired system with modern extensions

### 4.4 Free42 dynamic stack option

Free42 optionally provides dynamic depth while keeping classic RPN interaction.

### 4.5 8-level stack compromise

Community calculators often use 4/8-level selectable stacks as a balance between
simplicity and depth.

### 4.6 Concatenative programming languages

| Language | Focus |
|----------|-------|
| Forth | Low-level stack programming |
| Factor | Modern typed stack language |
| Joy | Pure concatenative functional style |
| PostScript | Stack model for page rendering |
| `dc` | Unix arbitrary-precision RPN calculator |

---

## 5. Comparative analysis for Calculatrix

### 5.1 Design options

| Option | Pros | Cons |
|--------|------|------|
| A) Fixed 4-level stack | Very simple, classic HP familiarity | Restrictive for nested workflows |
| B) Fixed 8-level stack | Better capacity, still simple | Silent overflow remains possible |
| C) Dynamic unlimited stack | No data loss, maximum power | More complex UI/scrolling |
| D) Hybrid: dynamic internal + 4-level visual window | Familiar UX + no internal data loss | More advanced UI logic |

### 5.2 Recommendation for Stage 2

Recommended: **Option D**.

Reasons:

1. Internal stack remains dynamic (RPL-style)
2. UI displays top 4 levels (HP familiarity)
3. Overflow indicator shows hidden depth (`+n more`)
4. Scroll/gesture reveals deeper levels
5. Explicit underflow errors (no silent duplication)

### 5.3 Operations to implement

Minimum viable set:

- ENTER (separator, no duplication)
- SWAP
- DROP
- DUP
- ROT
- CLEAR
- DEPTH
- UNDO

Stage 2 extensions:

- PICK n
- ROLL n
- OVER
- DUP2 / DROP2
- LAST-like recovery
- Drag-and-drop visual reordering

### 5.4 Improvements over HP-50g

| Improvement | Why |
|-------------|-----|
| Unlimited undo | Better recoverability for users |
| ENTER without duplication | Reduced onboarding confusion |
| Type badges in stack UI | Better object visibility |
| Explicit underflow error | Predictable behavior |
| Stack animations | Better mental model |
| Inline preview | Faster confidence while typing |

---

## 6. RPN evaluator implementation

### 6.1 Data model

```
Stack = List<StackObject>

StackObject =
  | RealNumber(value: double)
  | Expression(tokens: List<Token>)
  | Matrix(rows: List<List<double>>)
  | ...
```

### 6.2 Evaluation algorithm

```
function evaluate(input: Token[]):
  for token in input:
    match token:
      case Number(n):
        stack.push(RealNumber(n))
      case UnaryOp(op):
        a = stack.pop()
        stack.push(apply(op, a))
      case BinaryOp(op):
        b = stack.pop()
        a = stack.pop()
        stack.push(apply(op, a, b))
      case StackOp(cmd):
        executeStackCommand(cmd)
```

### 6.3 Infix to RPN conversion

To support algebraic mode over the same backend, use Shunting Yard conversion.
This allows Stage 1 (algebraic) and Stage 2 (RPN) to share one evaluator core.

---

## 7. RPN UX

### 7.1 Proposed screen layout

```
┌────────────────────────────┐
│ [+3 more]                  │
│                            │
│ 4:    12.5                 │
│ 3:    3.14159              │
│ 2:    42                   │
│ 1:    7.5         ← result │
├────────────────────────────┤
│ input: _                   │
└────────────────────────────┘
```

### 7.2 Visual feedback

- Push: top value enters with upward shift animation
- Pop: top value exits and stack compresses
- Swap: top two values cross-fade positions
- Error: stack shake + message

---

## 8. Sources

- Wikipedia: Reverse Polish notation
- Wikipedia: HP 49/50 series
- Wikipedia: RPL programming language
- HP-35 user manual (operational stack)
- HP 50g user guide
- Ball (1978), Agate & Drury (1980), Hoffman et al. (1994)
- Nelson (2012) on HP RPN evolution
- Wickes (1988), RPL language references
- newRPL and DB48X project docs
