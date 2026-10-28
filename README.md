# Calculatrix

> Ecosistema de cálculo matricial, numérico y simbólico: un lenguaje con dos
> notaciones (infix y RPN), motores que lo ejecutan y las herramientas para
> usarlo. Todo valor es una matriz: un escalar es 1x1.

**Misión:** `cx` quiere ser la mejor herramienta de cálculo para agentes,
humanos o IA. Ver [docs/mission.md](docs/mission.md). El camino está en
[docs/roadmap.md](docs/roadmap.md) y el trabajo en curso en
[docs/runbook.md](docs/runbook.md).

[![CI](https://github.com/ccisnedev/calculatrix/actions/workflows/ci.yml/badge.svg)](https://github.com/ccisnedev/calculatrix/actions/workflows/ci.yml)

## Paquetes

Cada paquete versiona por separado
([ADR 0002](docs/adr/0002-versioning-and-changelog-policy.md)); la versión
vigente está en su `pubspec.yaml`.

| Paquete | Qué es |
|---|---|
| [`code/core`](code/core) | `calculatrix`, el motor de referencia en Dart puro. Fuente semántica única. |
| [`code/cli`](code/cli) | `cx`, la línea de comandos sobre el core. |
| [`code/app`](code/app) | La calculadora Flutter (Android, Windows, web) sobre el core. |

El motor es Dart puro y de sala limpia: Giac se usa solo como oráculo en los
tests, nunca como núcleo
([ADR 0004](docs/adr/0004-pure-dart-engine-and-clean-room.md)).

## Primeros pasos

```bash
cd code/core && dart pub get && dart analyze && dart test
cd ../cli && dart pub get && dart analyze && dart test
cd ../app && flutter pub get && flutter analyze && flutter test
```

Los tests de `code/core` comparan resultados exactos contra Giac (`xcas`); sin
él se omiten salvo que se defina `CALCULATRIX_REQUIRE_GIAC=1`.

## Ejemplos CLI

El ejecutable es `cx`. Instalación y gramática completa en
[code/cli/README.md](code/cli/README.md).

```bash
cx '1 2 +'
cx eval rpn '1 2 +'
cx eval infix "2+3*4"
```

En cmd.exe (no PowerShell), una expresión con `^` debe ir entre comillas:
`cx eval infix "2^0.5"`.

## CI/CD

- `ci.yml`: analiza y prueba app, core (con Giac) y CLI, y construye la web.
- `pages-release.yml`: publica la web en https://calculatrix.ccisne.dev con un
  push a `main`.
- `cli-release.yml`: un push a `main` que cambia la versión de
  `code/cli/pubspec.yaml` crea el release `cli-vX.Y.Z` con `cx` para Windows y
  Linux.
- `windows-release.yml` y `android-release.yml`: al publicar un release `vX.Y.Z`
  de la app adjuntan el instalador y el `.aab`.

Ver [docs/release-checklist.md](docs/release-checklist.md) y
[docs/pub.md](docs/pub.md).

## Documentos

- [docs/architecture.md](docs/architecture.md): modelo del core.
- [docs/spec/](docs/spec): especificaciones de lo que existe.
- [docs/adr/](docs/adr): decisiones de arquitectura.
