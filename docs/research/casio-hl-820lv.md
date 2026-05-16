# Casio HL-820LV — Layout, Keys, and Features Reference

## Overview

The Casio HL-820LV is an 8-digit pocket calculator and a classic example of
compact calculator design from the 2000s-2010s. It uses immediate execution
(chain calculation / AES — Algebraic Entry System), where each binary operation
is executed when the next operator or `=` is pressed.

It does not use operator precedence and evaluates strictly left to right.

## Technical Specifications

| Property | Value |
|----------|-------|
| Display digits | 8 |
| Display type | 7-segment LCD |
| Power | Dual: Solar + Battery (LR1130 × 1) |
| Dimensions | ~100 × 62 × 9 mm |
| Weight | ~45g (with battery) |
| Body | Folding hard wallet-style cover |

## Button Layout

### Physical Distribution (4 columns × ~6 rows)

```
┌─────────────────────────────────────────┐
│            [ 8-DIGIT DISPLAY ]          │
│  Indicators: M  -  E                    │
├─────────────────────────────────────────┤
│                                         │
│   [MC]    [MR]    [M-]    [M+]          │
│                                         │
│   [OFF]   [√]     [%]     [÷]           │
│                                         │
│   [7]     [8]     [9]     [×]           │
│                                         │
│   [4]     [5]     [6]     [-]           │
│                                         │
│   [1]     [2]     [3]     [+]           │
│                                         │
│   [0]     [.]     [+/-]   [=]           │
│                                         │
│               [AC]  [C]                 │
│                                         │
└─────────────────────────────────────────┘
```

### Variant note

Some variants have a single dual-purpose `AC/C` key, or combined `ON/AC`.
Exact layout may differ slightly by region (HL-820LV-BK, HL-820LV-WE, etc.),
but feature behavior is equivalent.

## Full Key Catalog

### Numeric Keys (10)

| Key | Function |
|-----|----------|
| `0` - `9` | Digit input |
| `.` | Decimal point |

### Operation Keys (4)

| Key | Function | Behavior |
|-----|----------|----------|
| `+` | Add | Executes pending operation, sets addition as next operation |
| `-` | Subtract | Executes pending operation, sets subtraction as next operation |
| `×` | Multiply | Executes pending operation, sets multiplication |
| `÷` | Divide | Executes pending operation, sets division |

### Result Key

| Key | Function | Behavior |
|-----|----------|----------|
| `=` | Equals / Execute | Executes pending operation and shows result. Repeated presses repeat the last operation with the last operand |

### Memory Keys (4)

| Key | Function | Behavior |
|-----|----------|----------|
| `MC` | Memory Clear | Clears memory content (M → 0) |
| `MR` | Memory Recall | Displays value stored in memory |
| `M-` | Memory Subtract | Subtracts displayed value from memory |
| `M+` | Memory Add | Adds displayed value to memory |

### Special Keys

| Key | Function | Behavior |
|-----|----------|----------|
| `√` | Square root | Computes square root of displayed value immediately |
| `%` | Percentage | Context-dependent (see Percentage section) |
| `+/-` | Sign toggle | Inverts sign of displayed value |

### Control Keys

| Key | Function | Behavior |
|-----|----------|----------|
| `AC` | All Clear | Resets display, pending operation, accumulator. Does not clear memory |
| `C` | Clear Entry | Clears only current entry, keeps operation context |
| `OFF` | Power off | Turns calculator off (battery-only models; solar models may differ) |

## Display Indicators

| Indicator | Meaning |
|-----------|---------|
| `M` | A non-zero value is stored in memory |
| `-` | The displayed value is negative |
| `E` | Error (overflow, division by zero, square root of negative) |

## Detailed Functional Behavior

### Execution Model: Immediate Execution (Chain Calculation)

The HL-820LV uses AES without operator hierarchy:

```
Input: 2 + 3 × 4 =
Result: 20 (NOT 14)

Reason: (2 + 3) = 5, then 5 × 4 = 20.
Each operator executes the previous operation immediately.
```

### Evaluation Rule

1. User enters a number, which is shown on display
2. User presses an operator (`+`, `-`, `×`, `÷`): pending operation executes,
   result is shown, new operator becomes pending
3. User presses `=`: pending operation executes with current number

### Repeat Constant (`=` repeatedly)

```
5 + 3 = → 8
      = → 11  (8 + 3)
      = → 14  (11 + 3)
```

The last operand and operator are remembered for repeated equals.

### Percentage Behavior (`%`)

| Sequence | Interpretation | Result |
|----------|----------------|--------|
| `200 × 10 %` | 10% of 200 | 20 |
| `200 + 10 %` | 200 + 10% of 200 | 220 |
| `200 - 10 %` | 200 - 10% of 200 | 180 |
| `200 ÷ 10 %` | (200 ÷ 10) × 100 | 2000 (markup style) |

### Square Root (`√`)

- Immediate unary operation
- `9 √` → 3
- Square root of negative → Error (`E`)
- Chainable: `81 √ √` → 3

### Error Conditions

| Condition | Display |
|-----------|---------|
| Result > 99,999,999 | `E` (overflow) |
| Result < -99,999,999 | `E` (underflow) |
| Division by 0 | `E` |
| Square root of negative | `E` |

Error recovery: press `C` or `AC` to clear error state.

### Auto Power-Off

Calculator powers off automatically after ~7 minutes of inactivity
(in battery mode).

## Ergonomics and Visual Design

### Color-based Key Grouping

| Group | Typical color |
|-------|---------------|
| Digits (`0-9`, `.`) | Light gray / white |
| Operators (`+`, `-`, `×`, `÷`) | Dark gray |
| Equals (`=`) | Dark gray / blue |
| `AC` / `C` | Red / orange |
| Memory (`MC`, `MR`, `M-`, `M+`) | Medium gray |
| Functions (`√`, `%`, `+/-`) | Medium gray |

### Tactile Characteristics

- Flat membrane-style keys (slightly raised)
- Numeric key size: ~9mm × 7mm
- Key spacing: ~2mm
- Matte anti-slip body texture

## Implications for Calculatrix

### What we adopt from HL-820LV

1. 4-column layout (industry-standard and ergonomic)
2. Visual separation by key function groups
3. Prominent `=` key at lower-right position
4. Functional minimalism
5. State indicators (`M`, `-`, `E`)
6. Dual clear concept (`AC` and `C`)

### What we do not adopt

1. Immediate execution without precedence
2. No-parentheses behavior
3. Fully context-dependent `%` behavior
4. Auto power-off

## References

- Casio official product page: HL-820LV series
- Wikipedia: Calculator Input Methods — Immediate Execution / AES
- Casio HL-820LV user manual (multi-language booklet)
