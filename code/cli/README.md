# calculatrix_cli

The `cx` command-line interface for Calculatrix, built on `modular_cli_sdk`.
See `docs/spec/calculatrix_cli.md` for the full grammar and behavior, and
`docs/runbook-cli-stage-0.md` for how the CLI is being built in stages.

The executable is named `cx`. There is no `calculatrix` executable and no
alias of any kind: `cx` is what you run, directly (issue #22).

## Install (from source, for development)

```powershell
.\scripts\dev-install.ps1
```

Builds `cx.exe` from source and installs it under
`%LOCALAPPDATA%\calculatrix\bin`, adding that directory to the user `PATH`
if it is not already there. A legacy `cx.cmd` shim or `calculatrix.exe` from
an older install is removed if present.

## Install (a published release)

```powershell
irm https://calculatrix.ccisne.dev/install.ps1 | iex
```

```bash
curl -fsSL https://calculatrix.ccisne.dev/install.sh | bash
```

Downloads the newest `cli-v*` release from GitHub (never `releases/latest`,
since this repository's app releases are also tagged, as `vX.Y.Z`) and
installs `cx` with no alias of any kind. See `scripts/install.ps1` and
`install.sh` for what each one does step by step, and
`.github/workflows/cli-release.yml` for how a `cli-v*` release is built.

## Update, check and remove an install

```bash
cx upgrade --plan     # preview
cx upgrade --apply     # install the newest cli-v* release over this one
cx doctor              # check PATH and whether a newer release exists
cx uninstall --apply   # remove this install
```

## Run

```bash
dart run bin/cx.dart
```

## Try it

```bash
cx '1 2 +'
cx eval rpn '1 2 +'
cx eval infix "2+3*4"
```

```bash
cx 'pi'                        # ~3.14159265359
cx 'i dup *'                   # [[-1 0] [0 -1]], exact
cx eval infix 'e^(i*pi)'       # -1 as a matrix, to within 1e-14
cx commands list --category constants
```

The constants are `pi` (also `π`) and `e`, approximate, and `i`, the exact
matrix `[[0 -1] [1 0]]`. A constant is a name, not a number: in RPN write
`pi negate` and `pi approx`, not `-pi` or `~pi`; a matrix literal takes
numbers only.

A bare `cx` prints a short banner. `cx <program>` is a shortcut for
`cx eval rpn <program>`, so a single quoted RPN program can be evaluated
directly, without typing `eval rpn`.

## A note on `^` in cmd.exe

In cmd.exe (not PowerShell), `^` is the shell's own escape character and is
consumed while cmd.exe parses the command line, before `cx` ever starts. An
expression containing `^` must be quoted:

```bat
cx eval infix "2^0.5"
```

Typed unquoted, `cx eval infix 2^0.5`, the caret is already gone by the time
`cx` sees the arguments; no program, alias or executable can recover it,
because the shell itself consumed the character. `scripts\check-caret.ps1`
covers both the PowerShell and the cmd.exe form.

## Global options

`--json` for machine-readable output, `--quiet`/`-q` to suppress everything
but the result, `--help`/`-h` for help (the same catalog as `cx help`),
`--version` for the version (the same answer as `cx version`). They apply to
the `cx <program>` shortcut too, before or after the program:
`cx --json '1 3 /'` and `cx '1 3 /' --json` print what `cx eval rpn --json
'1 3 /'` prints. The options only `eval rpn` has, `--file` and `--stdin`, are
rejected by the shortcut with the full spelling to type. Exit codes
follow the SDK's own `ExitCode` table (0 ok, 7 validation failure, 64 usage error, 65 data error).
