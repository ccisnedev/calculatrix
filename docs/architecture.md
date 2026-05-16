# Architecture

## Overview

Calculatrix is a web-first Flutter calculator with algebraic evaluation.
It uses MVVM: the view observes a `ChangeNotifier` (controller) that coordinates the evaluation pipeline.

## Evaluation Pipeline

```
Input (String) → Tokenizer → List<Token> → Parser → AST → Evaluator → double
```

| Component | Responsibility |
|-----------|----------------|
| `Tokenizer` | String → tokens (numbers, operators, parentheses, √, %) |
| `Parser` | Recursive descent, PEMDAS precedence, builds a sealed AST |
| `Evaluator` | Pattern matching over AST → numeric result |
| `Controller` | ChangeNotifier, orchestrates the pipeline, manages memory and repeat `=` |

## AST (Sealed Classes)

```dart
sealed class AstNode {}
class NumberNode(double value)
class BinaryOpNode(AstNode left, TokenType op, AstNode right)
class UnaryOpNode(TokenType op, AstNode operand)
```

## Module Structure

```
code/app/lib/
  modules/
    calc/
      models/
        token.dart        # TokenType enum + Token class
        tokenizer.dart    # String → List<Token>
        parser.dart       # List<Token> → AstNode
        evaluator.dart    # AstNode → double
      controller.dart     # CalculatorController (ChangeNotifier)
      view.dart           # CalculatorView (Widget)
      calc.dart           # Barrel export
```

## Principles

- **TDD**: tests are written before implementation
- **Semantics-driven**: the entire UI has accessible labels
- **MVVM**: strict separation between view and logic
- **Immutability**: sealed AST, immutable `Token`
