# calculatrix_cli

The `calculatrix`/`cx` command-line interface, built on `modular_cli_sdk`.
See `docs/spec/calculatrix_cli.md` for the full grammar and behavior, and
`docs/runbook-cli-stage-0.md` for how the CLI is being built in stages.

## Install

```powershell
.\scripts\dev-install.ps1
```

Builds `calculatrix.exe` from source and installs it, plus a `cx.cmd` shim,
under `%LOCALAPPDATA%\calculatrix\bin`, adding that directory to the user
`PATH` if it is not already there.

## Run

```bash
dart run bin/calculatrix_cli.dart
```

## Try it

```bash
cx '1 2 +'
cx eval rpn '1 2 +'
cx eval infix "2+3*4"
```

A bare `cx` prints a short banner. `cx <program>` is a shortcut for
`cx eval rpn <program>`, so a single quoted RPN program can be evaluated
directly, without typing `eval rpn`.

## Global options

`--json` for machine-readable output, `--quiet`/`-q` to suppress everything
but the result, `--help`/`-h` for help. Exit codes follow the SDK's own
`ExitCode` table (0 ok, 7 validation failure, 64 usage error, 65 data error).
