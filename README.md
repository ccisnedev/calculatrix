# Calculatrix

> Calculadora multiplataforma matrix-first con un core canónico basado en
> stack machine y tres superficies visibles: `Infix`, `RPN` y `Matrix`.

[![CI](https://github.com/matarama-dev/calculatrix/actions/workflows/ci.yml/badge.svg)](https://github.com/matarama-dev/calculatrix/actions/workflows/ci.yml)

## Highlights (v0.4.10)

- `package:calculatrix` es la fuente semántica única para app y CLI.
- El core público expone `CalculatrixMachine`, comandos tipados, macros
  públicas, programas tipados e `CalculatrixSession`.
- `Infix` compila al mismo kernel matricial que usan `RPN` y los workflows
  directos por comando.
- En `v0.3.20`, el core compartido añade LU y QR como descomposiciones públicas
  y las expone en la máquina tipada, el CLI y la app `RPN`.
- `DET`, `LU` y `QR` viven sobre el mismo contrato stack-first: una operación
  simple devuelve una matriz escalar; una descomposición expande varios
  factores sobre la pila canónica.
- En `v0.3.21`, LU y QR quedan endurecidos con cobertura explícita para pivoteo,
  singularidad, matrices altas y columnas linealmente dependientes.
- En `v0.3.30`, el workstation `Matrix` puede lanzar LU y QR directamente hacia
  la pila canónica cuando entras desde `RPN`, sin perder el flujo de edición.
- En `v0.3.31`, Stage 4 queda cubierto también por un workflow end-to-end que
  mezcla creación matricial, macro en `RPN`, QR y retorno a `Infix`.
- `v0.4.0` cierra Stage 4 como release estable: determinante, LU, QR y sus
  workflows visibles quedan alineados entre core, app y CLI.
- En `v0.4.10`, el core añade eigenvalues reales para matrices `1x1` y `2x2`,
  el CLI los expone como `eig` y la app `RPN` los publica con `EIG` en el deck
  `FACT`.
- La línea `v0.3.1` mantiene `√` inmediato y `%` tipo Casio en `Infix`, sin
  alterar los contratos públicos de parser ni `RPN`.
- La app usa un solo teclado `6x4`: las cuatro filas inferiores permanecen
  fijas como calculadora clásica y solo las dos filas superiores cambian por
  deck según el modo activo.
- La app Flutter ofrece tres modos visibles: `Infix`, `RPN` y `Matrix`.
- El workstation matricial soporta edición estructural acotada `2x2` a `4x4`,
  presets, reordenamiento y confirmación canónica del literal final.
- El CLI soporta modos `infix`, `rpn`, `command` y `macro` sobre la misma
  API pública.
- En `command`, si una secuencia deja varios resultados, el CLI los imprime
  como `X0`, `X1`, `X2`, ... siguiendo el orden visible de la pila `RPN`.
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
dart run code/cli/bin/calculatrix_cli.dart command "[[2,1,1],[4,-6,0],[-2,7,2]]" lu
dart run code/cli/bin/calculatrix_cli.dart command "[[1,0],[0,2]]" qr
dart run code/cli/bin/calculatrix_cli.dart command "[[2,0],[0,3]]" eig
dart run code/cli/bin/calculatrix_cli.dart macro append-zero-row "[[1,2],[3,4]]"
```

## CI/CD

GitHub Actions valida core, app y CLI, y genera artefacto web en builds
exitosos.

## Roadmap

Ver [docs/roadmap.md](docs/roadmap.md) para el cierre de `v0.3.0`, el parche
`v0.3.1`, los slices `v0.3.10`, `v0.3.20`, `v0.3.21`, `v0.3.30`, `v0.3.31`, el
corte estable `v0.4.0` de Stage 4 y el primer slice `v0.4.10` posterior, y la
continuación del roadmap. Ver
también [docs/architecture.md](docs/architecture.md) para el modelo canónico actual.
