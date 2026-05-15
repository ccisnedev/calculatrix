# Calculatrix

> Calculadora multiplataforma con motor de evaluación algebraica y precedencia PEMDAS.
> Skin inspirado en la Casio HL-820LV.

[![CI](https://github.com/matarama-dev/calculatrix/actions/workflows/ci.yml/badge.svg)](https://github.com/matarama-dev/calculatrix/actions/workflows/ci.yml)

## Features (v1.0.0)

- Evaluación algebraica con precedencia de operadores (PEMDAS)
- Paréntesis y negación unaria
- Raíz cuadrada, porcentaje
- Memoria (MC, MR, M-, M+)
- Cambio de signo (±)
- Constante de repetición (= repetido)
- Precisión de 12 dígitos significativos
- Manejo de errores (÷0, √ negativo)

## Architecture

MVVM con Flutter — Controller extiende `ChangeNotifier`.

```
code/app/lib/modules/calc/
  models/       # Token, Tokenizer, Parser (AST), Evaluator
  controller.dart
  view.dart
```

Pipeline: `String → Tokenizer → Parser (AST) → Evaluator → double`

## Getting Started

```bash
cd code/app
flutter pub get
flutter test          # 124+ tests
flutter run -d chrome # Web
```

## CI/CD

GitHub Actions ejecuta `flutter analyze` + `flutter test` en cada push/PR, y genera artefacto web en build exitoso.

## Roadmap

Ver [docs/roadmap.md](docs/roadmap.md) para etapas futuras (RPN, matrices).
