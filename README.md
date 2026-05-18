# Calculatrix

> Calculadora multiplataforma matrix-first con un core canónico basado en
> stack machine y tres superficies visibles: `Infix`, `RPN` y `Matrix`.

[![CI](https://github.com/matarama-dev/calculatrix/actions/workflows/ci.yml/badge.svg)](https://github.com/matarama-dev/calculatrix/actions/workflows/ci.yml)

## Highlights (v3.1.0)

- `package:calculatrix` es la fuente semántica única para app y CLI.
- El core público expone `CalculatrixMachine`, comandos tipados, macros
  públicas, programas tipados e `CalculatrixSession`.
- `Infix` compila al mismo kernel matricial que usan `RPN` y los workflows
  directos por comando.
- En `v3.1.0`, el core compartido añade determinante como operación pública y
  lo expone en la máquina tipada, el CLI y la app mediante `DET`.
- La línea `v3.0.1` mantiene `√` inmediato y `%` tipo Casio en `Infix`, sin
  alterar los contratos públicos de parser ni `RPN`.
- La app usa un solo teclado `6x4`: las cuatro filas inferiores permanecen
  fijas como calculadora clásica y solo las dos filas superiores cambian por
  deck según el modo activo.
- La app Flutter ofrece tres modos visibles: `Infix`, `RPN` y `Matrix`.
- El workstation matricial soporta edición estructural acotada `2x2` a `4x4`,
  presets, reordenamiento y confirmación canónica del literal final.
- El CLI soporta modos `infix`, `rpn`, `command` y `macro` sobre la misma
  API pública.
- La política numérica, los errores tipados y la memoria matricial viven en el
  core compartido.

## Superficies públicas

- `code/core`: paquete Dart público `calculatrix`.
- `code/app`: shell Flutter sobre el core compartido.
- `code/cli`: interfaz de línea de comandos sobre el mismo vocabulario público.

## Arquitectura

La lógica matemática y operativa vive en `package:calculatrix`. Flutter y CLI
son capas consumidoras sobre ese mismo núcleo.

```
code/core/lib/
  calculatrix.dart
  src/
    machine/      # stack machine, typed commands, macros, programs
    evaluation/   # compileInfix, evaluateInfix, evaluateRpn
    matrix/       # Matrix y display formatting
    session/      # interactive shared session facade
    errors/       # public typed error taxonomy

code/app/lib/modules/calc/
  controller.dart  # presentation adapter over CalculatrixSession
  view.dart        # shell Infix/RPN/Matrix y workstation UI

code/cli/bin/
  calculatrix_cli.dart
```

## Primeros pasos

```bash
cd code/core
dart analyze
dart test

cd ../cli
dart analyze
dart test

cd ../app
flutter pub get
flutter analyze
flutter test
flutter test integration_test/calculator_test.dart -d windows
```

## Ejemplos CLI

```bash
dart run code/cli/bin/calculatrix_cli.dart infix "[[1,2],[3,4]] * [[2]]"
dart run code/cli/bin/calculatrix_cli.dart command "[[1,2],[3,4]]" transpose
dart run code/cli/bin/calculatrix_cli.dart command "[[4,7],[2,6]]" det
dart run code/cli/bin/calculatrix_cli.dart macro append-zero-row "[[1,2],[3,4]]"
```

## CI/CD

GitHub Actions valida core, app y CLI, y genera artefacto web en builds
exitosos.

## Roadmap

Ver [docs/roadmap.md](docs/roadmap.md) para el cierre de `v3.0.0`, el parche
`v3.0.1`, el slice `v3.1.0` de determinante y la continuación de Stage 4. Ver
también [docs/architecture.md](docs/architecture.md) para el modelo canónico actual.
