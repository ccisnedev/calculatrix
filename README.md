# Calculatrix

> Calculadora multiplataforma matrix-first con semántica compartida entre
> `Infix` y `RPN`.

[![CI](https://github.com/matarama-dev/calculatrix/actions/workflows/ci.yml/badge.svg)](https://github.com/matarama-dev/calculatrix/actions/workflows/ci.yml)

## Features (v2.12.0)

- Motor compartido `package:calculatrix` para app y CLI
- Editor matricial refinado con selección directa `2x2` a `4x4`, presets
  `Zeros`/`Identity`, y validación explícita por celda
- Evaluación `Infix` y `RPN` sobre la misma semántica matricial
- División matricial por denominadores escalares `1x1`
- Raíz cuadrada de matrices cuadradas con errores explícitos en dominio real
- Memoria matricial (`MC`, `MR`, `M+`, `M-`) y cambio de signo (`±`) en el core
- Valor comprometido compartido entre `Infix` y `RPN`
- Errores tipados y política numérica determinista

## Architecture

La lógica matemática y operativa vive en `package:calculatrix`.
Flutter y CLI son capas de interfaz sobre ese core compartido.

```
code/core/lib/src/
  matrix/       # Matrix, formatting, matrix algebra
  rpn/          # RPN engine and stack primitives
  evaluation/   # infix/rpn facade
  session/      # shared calculator state and matrix memory

code/app/lib/modules/calc/
  controller.dart  # presentation adapter over CalculatrixSession
  view.dart        # Flutter UI

code/cli/bin/
  calculatrix_cli.dart
```

## Getting Started

```bash
cd code/core
dart test

cd ../cli
dart test

cd ../app
flutter pub get
flutter test test
flutter analyze
flutter run -d chrome
```

## CI/CD

GitHub Actions valida core, app y CLI, y genera artefacto web en builds
exitosos.

## Roadmap

Ver [docs/roadmap.md](docs/roadmap.md) para la hoja de ruta y la entrada
v2.12.0 de refinamiento UX del editor matricial.
