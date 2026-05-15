# Architecture

## Overview

Calculatrix es una calculadora Flutter web-first con evaluación algebraica.
Usa MVVM: la vista observa un `ChangeNotifier` (controller) que coordina el pipeline de evaluación.

## Pipeline de Evaluación

```
Input (String) → Tokenizer → List<Token> → Parser → AST → Evaluator → double
```

| Componente | Responsabilidad |
|-----------|----------------|
| `Tokenizer` | String → tokens (números, operadores, paréntesis, √, %) |
| `Parser` | Recursive descent, precedencia PEMDAS, genera AST sealed |
| `Evaluator` | Pattern matching sobre AST → resultado numérico |
| `Controller` | ChangeNotifier, orquesta pipeline, maneja memoria y repeat = |

## AST (Sealed Classes)

```dart
sealed class AstNode {}
class NumberNode(double value)
class BinaryOpNode(AstNode left, TokenType op, AstNode right)
class UnaryOpNode(TokenType op, AstNode operand)
```

## Estructura de Módulos

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

## Principios

- **TDD**: tests escritos antes de la implementación
- **Semantics-driven**: toda la UI tiene labels accesibles
- **MVVM**: separación estricta vista ↔ lógica
- **Inmutabilidad**: AST sealed, Token inmutable
