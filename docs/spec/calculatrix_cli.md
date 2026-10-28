# Calculatrix CLI Specification

Status: Describes cx 0.16.3.
Program: `cx` (`code/cli`, package `calculatrix_cli`), on `modular_cli_sdk`
^0.11.0 and `cli_router` ^0.2.1.
Core: `calculatrix` (`code/core`). The language itself (literals, words,
infix grammar, error ids) is specified in `docs/spec/calculatrix_core.md`;
numeric semantics (exactness, `power`, limits) in
`docs/spec/calculatrix_mathematics.md`. This document covers only what `cx`
adds: routes, argument grammar, output, exit codes and the installed tool.

## 1. Purpose

`cx` takes one input, a program as a string, and runs it. The program is RPN
or infix, and the user always says which. It is the same language the app
runs from its keypad.

`cx` has three parts:

1. **Evaluation**: `cx eval rpn`, `cx eval infix`, and the shortcut
   `cx <program>` for RPN.
2. **Encyclopedia**: `cx commands list | show | search` find a word and
   explain it (section 7).
3. **Maintenance**: `cx version`, `cx doctor`, `cx upgrade`, `cx uninstall`
   keep the installed CLI healthy.

## 2. Principles

1. **One input.** A program string. Everything else is infrastructure.
2. **Declared, not guessed.** Every route, option and positional is declared
   once, with its type and cardinality. The parser reads the declaration
   before the arguments. There is no fallback, no second attempt after a
   failure, and no reinterpretation of a value.
3. **Explicit over default.** `cx` declares no default except the digit limit
   (section 6), which `--help` shows.
4. **One form.** Each thing is written one way. Where a standard exists
   (POSIX/GNU for argument order, `sysexits` for exit codes), `cx` follows it.
5. **Reject what is ambiguous.** When an invocation could mean two things, it
   is rejected, and the message gives the correct form.
6. **Start strict.** A form rejected today can become valid later without
   breaking anyone; the reverse is a breaking change. Every form not listed
   here is an error.
7. **The core owns the language.** The CLI parses arguments, reads the
   program, calls core and formats output. Names, aliases, search terms and
   documentation of words live in the core registry, shared with the app.

## 3. Routes

| Route | Kind | Contract | What it does |
|---|---|---|---|
| `cx` | query | globals | Banner (below). Never reads stdin. |
| `cx <program>` | query | one operand; `--max-digits`; `--json`, `-q` | Shortcut: same as `cx eval rpn <program>` (G3, G4). |
| `cx eval rpn [<program>]` | query | `--file`, `--stdin`, `--max-digits`; exactly one source (G1) | Runs an RPN program on an empty stack and prints the stack it leaves. |
| `cx eval infix [<expression>]` | query | same as `eval rpn` | Evaluates an infix expression; always leaves one value. |
| `cx commands list` | query | `--category <name>` | Lists the registry, grouped by category. |
| `cx commands show <name>` | query | one operand | The entry of one word, by name or alias. |
| `cx commands search <text>` | query | one operand | Finds words (section 7). |
| `cx version` | query | globals | Prints `cx: <version>`. |
| `cx doctor` | query | globals | Checks the installation; changes nothing. |
| `cx upgrade` | command | `--plan` or `--apply` [`--autoapprove`] | Installs the newest `cli-v*` release. |
| `cx uninstall` | command | `--plan` or `--apply` [`--autoapprove`] | Removes the CLI. |
| `cx help [<topic>]`, `--help`, `-h` | query | | Help (section 8.6). |

`version`, `doctor`, `upgrade` and `uninstall` come from the standard plugins
of `modular_cli_sdk` (section 8.7). There is no `cx install`: the release's
install scripts (`install.ps1`, `install.sh`) do the first installation,
because `cx` does not exist yet at that point.

**Queries and commands.** A query changes nothing. `upgrade` and `uninstall`
change the installation, so they are commands: `--plan` shows the steps and
stops; `--apply` shows them, asks for approval, then performs them;
`--autoapprove` skips the prompt (for agents and CI). Neither `--plan` nor
`--apply` is a default: `cx upgrade` alone is `validation-failed`, 7, with a
message explaining both.

**Banner.** Bare `cx` prints the logo (glow `#2EF2C3`, square box-drawing
brackets), the version and tagline, the overview, a `Commands:` block listing
only the routes the CLI registers, each with a runnable example, and a
`Quickstart:` line. Colour is used only when stdout is a terminal that
supports ANSI escapes and `NO_COLOR` is unset (any value, even empty,
disables it). The glow is 24-bit when `COLORTERM` is `truecolor` or `24bit`,
otherwise ANSI 96 (bright cyan). With `--json` the banner is
`{"name": "cx", "tagline": "...", "version": "..."}`.

**Overview.** One text, defined once in code (`overview.dart`), shown by the
banner, the epilog of `cx --help` and both install scripts, so they cannot
disagree. It presents RPN, infix, matrices and exact/approximate values with
equal weight, says that one program can leave several results, and mentions
no feature that does not exist yet (no symbolic form). Every example in it is
run by a test.

**`cx doctor`.** Runs every check contributed to the extension point
`doctor.checks`:

| Check | From | ok | warning | error |
|---|---|---|---|---|
| `path` | `cx` itself | `cx` found on `PATH` | | not found |
| `release` | `InstallationPlugin` | up to date | a newer `cli-v*` release exists, or the lookup failed (reason printed) | |

A warning never fails the command, and a failed lookup is reported, never
skipped. Exit 0 when no check is an error. Otherwise exit 78, with the error
`doctor-check-failed` carrying every result: in JSON,
`{"error": {"id": "doctor-check-failed", "message": "1 check(s) failed: path", "exitCode": 78, "checks": [...]}}`.
Success in JSON is `{"checks": [{"name": "path", "status": "ok", "detail": "..."}, ...]}`.

**Releases.** `upgrade` and `doctor` look up releases in
`ccisnedev/calculatrix`, considering only tags with the prefix `cli-v` and
never `releases/latest`, because the app's `vX.Y.Z` releases live in the
same repository (tag rules: `docs/adr/0002-versioning-and-changelog-policy.md`,
section 5). Assets: `cx-windows-x64.zip`, `cx-linux-x64.tar.gz`.

## 4. Invocation grammar

```text
cx                                         banner
cx [options] <program>                     shortcut: RPN, one operand
cx eval rpn [options] <program>            RPN program, inline
cx eval rpn [options] --file <path>        RPN program from a file
<source> | cx eval rpn [options] --stdin   RPN program from stdin
cx eval infix [options] <expression>       the same three sources, infix
cx commands list [--category <name>]
cx commands show <name>
cx commands search <text>
cx version | doctor | help [<topic>]
cx upgrade --plan | --apply [--autoapprove]
cx uninstall --plan | --apply [--autoapprove]
```

Options of `eval rpn` and `eval infix`:

| Option | Kind | Meaning |
|---|---|---|
| `-f, --file <path>` | value: path, must exist | read the program from a file |
| `--stdin` | flag | read the program from stdin |
| `--max-digits <n>` | value: integer, at least 1 | digit limit of exact numbers (section 6); default 10000 |

Global options, on every route including the shortcut:

| Option | Meaning |
|---|---|
| `--json` | output as JSON (section 6) |
| `-q, --quiet` | suppress progress messages, never results or errors; only `upgrade` and `uninstall` emit any |
| `-h, --help` | help (section 8.6) |

### Rules

- **G1. Exactly one program source.** `eval rpn` and `eval infix` take the
  program from exactly one of: the inline operand, `--file`, `--stdin`. None,
  or two or more, is `validation-failed`, 7.
- **G2. Stdin is read only when asked.** Without `--stdin`, `cx` never reads
  stdin, terminal or not. There is no "data waiting" check: it can block
  forever when a parent leaves stdin open, and the result would depend on
  how `cx` was launched. `'1 2 +' | cx` shows the banner.
- **G3. The shortcut is a declared root route.** `cx <program>` is the route
  `<program>` at the root, resolved in the same single pass as every route.
  At each position a literal route word wins over a parameter, so
  `cx version` is always the route and `cx commands shwo power` is an error
  of the `commands` module, never a program.
- **G4. The shortcut takes one operand.** RPN only, inline only. It accepts
  `--max-digits` and the global options (`--json`, `-q`), before or after
  the program. `--file` and `--stdin` are `unknown-option`, 7, with the full
  spelling: `cx '1 2 +' --file p.txt` gives "--file is not accepted by the
  shortcut; use: cx eval rpn '1 2 +' --file p.txt". More than one operand
  (an unquoted program) is `extra-argument`, 64: "cx received 3 arguments;
  quote the program as one argument: cx '1 2 +'" (section 9 explains why),
  also with `--json` (the same message in the error object) and with `-q`.
- **G5. Reserved words.** The root route words `eval`, `commands`,
  `version`, `doctor`, `upgrade`, `uninstall`, `help` are never programs, so
  no RPN word, alias or search term may be one of them. Adding a root route
  is a breaking change of the CLI: a word that used to be a program becomes
  a route.
- **G6. Order: route, then options and operands.** The route words come
  first and are never preceded or interrupted by an option:
  `cx --json version`, `cx -q upgrade --plan` and `cx eval -f p.rpn rpn` are
  `misplaced-option`, 7. After the route, `cx` follows GNU `getopt` order by
  default: an option may follow an operand, and is moved in front of it, so
  `cx eval rpn '1 2 +' --json` is identical to `cx eval rpn --json '1 2 +'`.
  With `POSIXLY_CORRECT` set (any value, read from the real environment),
  strict POSIX order applies: an option after an operand is
  `misplaced-option`, 7. The shortcut's route is empty, so `cx --json '1 2 +'`
  is valid in both modes.
- **G7. A flag is present or absent.** `--json=true` is `unexpected-value`,
  7. There is no negation: `--no-json` is an unknown option. Absent always
  means no.
- **G8. A value option requires its value.** The forms are `-f p.rpn`,
  `--file p.rpn` and `--file=p.rpn`. `cx eval rpn -f` is `missing-value`, 7.
  The next token is taken as the value only if it does not look like an
  option; a value starting with `-` is written `--file=-x.rpn`. A repeated
  option is `repeated-option`, 7.
- **G9. Short options stand alone.** `-qh` is `invalid-short-option`, 7:
  "short options stand alone: -q -h". `-fp.rpn` too: "the value goes apart:
  -f p.rpn".
- **G10. `--` ends the options.** Everything after it is an operand,
  including `--help`: `cx eval rpn --json -- '-x'`, `cx -- '-1 2 +'`. When
  an argument rejected as an option looks like a value (after its `-` it has
  a digit, an operator, a bracket, `~`, a space, or it is a registry word or
  constant such as `-e`), the message says so and gives the command with the
  value last, after `--`: `cx eval infix '-sqrt(-1)'` reports "-sqrt(-1)
  starts with "-", so it was read as options; to pass it as a value, end the
  options with --: cx eval infix -- '-sqrt(-1)'". The id and exit code stay
  those of the SDK. `--` inside a program is an error of core that names the
  form to type (`cx '1 -- 2'`).
- **G11. Negative numbers are operands.** A token looks like an option only
  if it is `-` followed by a letter, `--` followed by a letter, or exactly
  `--`. So `cx '-1 2 +'` and `cx eval infix '-(2+3)'` need no `--`.
- **G12. A program has tokens.** An empty or blank program is
  `validation-failed`, 7, "the program is empty", from any source: `cx ''`,
  an empty file, an empty stdin.

### Not supported

- **Detecting infix vs RPN.** `2 -3` is two stack entries in RPN and `-1` in
  infix. The mode is always a route.
- **A stack that persists between invocations** (`cx push 3`, then `cx +`).
  That would be hidden state on disk.
- **`--trace`, `--show-rpn`.** Not designed yet (`docs/roadmap.md`); today
  they are unknown options, 7.

## 5. Output streams

The result goes to stdout; every error goes to stderr, in text and in JSON.
Text output ends with a newline. JSON results are pretty-printed; JSON errors
are one compact line.

## 6. Output and errors

**Text (default).** HP 50g style: one line per level, `level: value`, level 1
at the bottom; matrices with spaces, `[[0 -1] [1 0]]`. `eval rpn` and the
shortcut print every level the program leaves, with no limit; an empty stack
(`cx '1 drop'`) prints an empty line and exits 0. `eval infix` always prints
one level.

A value is exact or approximate as a whole
(`docs/spec/calculatrix_mathematics.md`, section "Exactness"):

- An exact value prints in full, never rounded: an integer as an integer, a
  rational with at most 20 digits after the point as a decimal, any other
  rational as a fraction (`0.1 0.2 +` prints `0.3`, `1 3 /` prints `1/3`,
  `1 1073741824 /` prints `1/1073741824`).
- An approximate value goes through the display formatter of core, the one
  the app uses: at most 12 significant digits, trailing zeros removed, with
  the mark `~` once in front of the whole value: `~1.41421356237`,
  `~[[-2 1] [1.5 -0.5]]`. The stored value is unchanged; JSON keeps the full
  double.

Every text output can be typed back as a literal (`~`, `p/q`; see
`docs/spec/calculatrix_core.md`, section "Literals").

```text
$ cx '2 sqrt 1 3 /'
2: ~1.41421356237
1: 1/3
```

**JSON (`--json`).**

```json
{"stack": [{"level": 2, "exact": false, "value": 1.4142135623730951},
           {"level": 1, "exact": true, "value": "1/3"}]}
```

- One object per level, in the text order: highest level first, level 1
  last. An empty stack is `{"stack": []}`.
- `exact` says whether the value is exact.
- A 1x1 matrix is a single number. Any other matrix is an array of rows,
  never flattened: `0 1 2 vector` is `[["0"], ["1"]]`.
- An exact number is a string in its text form (`"3/5"`,
  `"12157665459056928801"`), since a JSON number cannot hold it. An
  approximate number is a JSON number with the full double. `Infinity` and
  `NaN` never appear: a non-finite value is the error `non-finite`.

**Exit codes.**

| Code | SDK name | Meaning | Examples |
|---|---|---|---|
| `0` | `ok` | success | |
| `1` | `genericError` | a step of `upgrade --apply` or `uninstall --apply` failed (`step-failed`) | download failed, access denied |
| `2` | `apiError` | the release lookup failed (`release-lookup-failed`) | no network, GitHub API error |
| `4` | `notFound` | the newest `cli-v*` release has no asset for this platform (`asset-not-found`) | |
| `7` | `validationFailed` | the route is right, an option or value is wrong | unknown, misplaced or repeated option, missing value, two program sources, empty program, file not found, `upgrade` without `--plan`/`--apply` |
| `64` | `invalidUsage` | the invocation names no route (`EX_USAGE`) | `incomplete-command`, `missing-argument`, `extra-argument` |
| `65` | `dataError` | the program ran and failed (`EX_DATAERR`) | every error of core: `unknown-word`, `stack-underflow`, `syntax-error`, `limit-exceeded`, ... |
| `78` | `configError` | the installation is wrong (`EX_CONFIG`) | `doctor-check-failed`, `platform-not-supported` |

`64`, `65` and `78` come from `sysexits.h`; `7` is the SDK's convention. A
failed `--apply` stops at the failed step and reports the steps already done;
it neither rolls back nor retries. A refused approval is `approval-refused`.

**Errors in text.** `Error: <message> [<id>]`, then one `  key: value` line
per detail, then the usage of the route when one was resolved, or the line
`Run "cx --help" to see every command.`

**Errors in JSON.** Every error, from the router, the SDK, a plugin or core,
has one shape:

```json
{"error": {"id": "stack-underflow", "message": "...", "exitCode": 65,
           "details": {"token": "+", "position": 3}}}
{"error": {"id": "unknown-option", "message": "unknown option '--bogus'",
           "exitCode": 7, "contract": {"route": "eval rpn [<program>]", "...": "..."}}}
```

- `id` (kebab-case), `message` and `exitCode` (the process exit code) are
  always present. There is no `isRetryable`.
- Other fields appear only when they apply: `details` (core errors:
  `token`, `position` as the 1-based character offset, `suggestions`,
  `name`, `routeSuggestion`, `limit`, `estimated`; validation errors:
  `parameter`), `contract` for usage errors on a resolved route, `checks`
  for `doctor-check-failed`.

**Core errors.** All exit 65 and carry the id of core, so scripts branch on
the id, not the code. The ids and their meaning belong to core
(`docs/spec/calculatrix_core.md`, section "Errors"; `power`'s errors
in `docs/spec/calculatrix_mathematics.md`, section "power"). The CLI only
renders them, adding two things: the route suggestion of the shortcut
(section 7) and the hint of `limit-exceeded` below.

**Size limit.** An exact result whose numerator or denominator would have
more digits than the limit is `limit-exceeded`, raised before the
computation when the size can be estimated, never an approximate result
instead (estimates: `docs/spec/calculatrix_mathematics.md`, section
"Exactness"). `details` carry `limit` and `estimated`, and the message gives
the next step: the same command with `approx` before the failing word, or
`~` before a failing literal, and `--max-digits`. The default limit is 10000
digits; `--max-digits <n>` on `eval rpn`, `eval infix` and the shortcut sets
it and must be at least 1.

```text
$ cx '3 1000000 ^'
Error: 3^1000000 has about 477122 digits, over the limit of 10000; for an approximate result: cx '3 1000000 approx ^', or raise the limit with --max-digits. [limit-exceeded]
  token: ^
  position: 11
  limit: 10000
  estimated: 477122
```

## 7. The encyclopedia: `cx commands`

Every word of the core registry carries its own documentation; the CLI and
the app only render it (registry rules: `docs/spec/calculatrix_core.md`,
section "Command registry"). `cx commands list` is the authoritative list of
words; no document keeps a copy.

`cx commands show <name>` prints, for one word: name and aliases, category,
definition (`primitive`, or the RPN program of a defined word: `inverse` is
`-1 power`), search terms, HP 50g reference, stack effect, preconditions,
description, examples and errors. A test of core runs every example, so an
entry cannot drift from what the word does.

- `show` resolves aliases: `show ^` shows `power`, `show √` shows `sqrt`.
- `search <text>` matches name, aliases, HP reference, search terms and
  description, one line per word, or `No matches.` (exit 0):
  `search column` finds `vector`, `append-cols`, ...; `search hcat` finds
  `append-cols`.
- `list --category <name>` lists one category. The categories are an
  enumeration taken from the registry; an unknown one is `validation-failed`,
  7, naming the valid ones.
- `--json` returns the same entries for agents and scripts.

**Aliases and search terms differ.** An alias is a word of the language: `^`
runs `power`. A search term only finds the entry: `hcat` is not a word, so
`cx hcat` fails with `unknown-word` and suggests `append-cols`.

**"Did you mean".** Two vocabularies, two owners:

- **Words**, from the core registry (shared with the app): `cx hcat`
  suggests `append-cols` (`details.suggestions`).
- **Routes**, from the SDK catalog: `cx commands shwo power` is
  `incomplete-command`, 64, suggesting `show`.

A typo at the root is a program, because of the shortcut: `cx verison` runs
the program `verison` and fails with `unknown-word`, 65. Only on the
shortcut, the CLI adds the closest route, as a separate suggestion: "Did you
mean the command 'cx version'?" (`details.routeSuggestion`). A route is
suggested only when the whole route is close to the typo, never a bare
fragment of a multi-word route. This is the one cost of the shortcut.

## 8. Implementation on `modular_cli_sdk`

All of this is a capability of `cli_router` or `modular_cli_sdk`; `cx` only
declares (`code/cli/lib/src/cli_builder.dart`).

### 8.1 Resolution

Routes form a trie. At each node an operand not after `--` takes the literal
child with that text if there is one; otherwise it binds the node's
parameter; otherwise the invocation is rejected. The decision is local: a
later failure never moves the invocation to another branch. Declaration
errors (duplicate routes, an optional segment not last, a positional with no
segment) fail when the CLI is built, never at run time.

### 8.2 Options

The router knows each option's shape (flag or value, abbreviation,
required, repeatable); the SDK knows its type (`string`, `flag`, `integer`,
`path`, `enumeration`), and each type converts text or fails with 7. Every
field that changes behavior is written in the declaration. The option
errors are `unknown-option`, `misplaced-option`, `missing-value`,
`unexpected-value`, `invalid-short-option` and `repeated-option` (7); the
route errors are `incomplete-command`, `missing-argument` and
`extra-argument` (64). There is no `unknown-command` in `cx`: an unknown root
word is a program (G3). An unknown help topic is not a program:
`cx help nope` is `unknown-help-topic`, 64, with a "did you mean" when a
command is close.

### 8.3 Contracts

A route's pattern says where it is; its contract says what it accepts. The
cardinality of positionals comes from the pattern: `<name>` exactly one,
`[<name>]` (last only) zero or one, none: any operand is `extra-argument`,
64. Constraints between fields (`ExactlyOne(program, file, stdin)`) are
checked before the query runs. The empty-program rule (G12) applies to the
text after it is read, so the eval queries check it.

### 8.4 Defaults

The router applies no defaults. `cx` relies on one: the digit limit when
`--max-digits` is absent (10000, shown by `--help`).

### 8.5 Rejections

A rejection belongs to the node that was reached; a consumed route word never
returns to the root. `cx version junk` is `extra-argument`; `cx commands
show` is `missing-argument`; `cx eval` is `incomplete-command`, listing `rpn`
and `infix`.

`cx` rewrites three SDK messages to make them actionable, keeping the id and
the exit code: the unquoted program (G4), the option the shortcut does not
take (G4, also changing `misplaced-option` to `unknown-option`), and the
value that starts with `-` (G10).

### 8.6 Help

`cx --help`, `cx -h` and `cx help` print the catalog of routes, the global
options, then the overview (section 3) and two hints: every route takes its
own `--help`, and a program starting with `-` goes after `--`.
`cx <route> --help` and `cx help <module>` print the usage of that route or
module, exit 0; `cx help <topic>` with no such route or module is
`unknown-help-topic`, 64. Help is decided after resolution, so `--` is honored:
`cx eval rpn -- --help` evaluates the program `--help`.

**Precedence.** When `-h` or `--help` is read before `--`, help wins over
`incomplete-command`, `missing-argument`, `missing-required-option` and the
contract constraints: `cx eval --help` and `cx eval rpn --help` exit 0. Help
loses to `unknown-command`, `extra-argument` and every option error, because
then the invocation is malformed: `cx eval rpn --bogus --help` is
`unknown-option`, 7.

### 8.7 Plugins

A plugin is active only when `cx` registers it; the SDK adds none by itself.
Plugin routes live at the root, go through the same resolution, contracts and
rejections, and are reserved words (G5). Plugins that `cx` registers:

| Plugin | Routes | Notes |
|---|---|---|
| `VersionPlugin` | `version` | version `0.16.3`, the same constant `ModularCli` gets |
| `DoctorPlugin` | `doctor` | declares `doctor.checks` |
| `BinaryOnPathDoctorPlugin` (`cx`'s own) | | contributes the `path` check |
| `InstallationPlugin` | `upgrade`, `uninstall` | repository `ccisnedev/calculatrix`, tag prefix `cli-v`, executable `cx`, assets per platform; contributes the `release` check |

## 9. Rejected designs

- **Unquoted programs.** A program is always one quoted argument; operands
  are never joined. Joining would need no quotes in PowerShell, but other
  shells change the words before `cx` sees them, so a join would silently run
  a program the user did not type. What `cx` receives (Windows 11, `cx`
  0.15.0; zsh as documented, not run):

  | Typed | bash (Git Bash) | zsh | PowerShell | cmd.exe |
  |---|---|---|---|---|
  | `cx 5 7 power` | 3 arguments, 64 | same | same | same |
  | `cx 2 3 *` | `*` is a glob: file names, or `*` when none match; 64 | `*` is a glob; with no match zsh stops and `cx` does not run | 3 arguments, 64 | 3 arguments, 64 |
  | `cx [[1 2] [3 4]] inverse` | 5 arguments, 64 | `[[1` is a glob with no match: `cx` does not run | 5 arguments, 64 | 5 arguments, 64 |
  | `cx 2 3 ^` | 3 arguments, 64 | with `EXTENDED_GLOB`, `^` is a glob operator | 3 arguments, 64 | `^` is cmd's escape: `cx` gets `2 3`, 64 |
  | `cx '5 7 power'` | 1 argument, `78125` | same | same | no single quotes in cmd: 3 arguments, 64; `cx "5 7 power"` works (inside double quotes `^` is literal) |

  One quoted argument is the only form that works in every shell.
- **A `batch` route.** Several results in one call are already one program
  that leaves several values: `cx '2 sqrt 1 3 /'`. Labels and isolated
  evaluation (HP `->TAG`, `IFERR`) need name literals and program values
  (issue #79).
- **A `calculatrix` executable, or an alias or shim.** The executable is
  `cx` (`cx.exe`), with nothing in between. A `.cmd`/`.bat` shim runs
  through cmd.exe, which consumes `^` while parsing the command line, so
  `cx eval infix 2^0.5` would lose the `^` before any executable starts. The
  contract is that `cx` receives exactly the argv the calling shell
  produced.
- **Fallback re-dispatch** (route `cx <program>` from the not-found path by
  running again with `eval rpn` in front). It retries after a failure and
  captured `cx commands show` and `cx --json version` as programs (G3).
- **Auto-detecting infix.** `2 -3` has two readings.
- **Reading stdin when it is not a terminal.** The result would depend on
  how the process was launched, and the check can block (G2).
- **`--flag=true`, `--no-flag`, clusters (`-qh`), attached short values
  (`-fp.rpn`).** With no defaults, absent already means no; each extra form
  adds error cases. Any of them can be added later without breaking anyone.
- **`cx install`.** Installation happens before `cx` exists.
- **Aliases `hcat`, `vcat`.** They are search terms: they find
  `append-cols`/`append-rows` without adding words to the language.

## 10. Behavior table

Each row is checked against `cx` 0.16.3; most are tests in `code/cli/test`.

| Invocation | Result and exit code |
|---|---|
| `cx` | banner, 0 |
| `'1 2 +' \| cx` | banner, 0; stdin is not read (G2) |
| `cx '1 2 +'`, `cx '-1 2 +'` | `1: 3`, `1: 1`, 0 |
| `cx ''`, `cx '   '` | `validation-failed`, 7: the program is empty (G12) |
| `cx 1 2 +` unquoted | `extra-argument`, 64, with the quoting hint (G4) |
| `cx '[[1 2]'` | `syntax-error`, 65 |
| `cx --json 1 2 +`, `cx -q 1 2 +` | `extra-argument`, 64, with the quoting hint (G4) |
| `cx eval rpn` | `validation-failed`, 7: give one of `<program>`, `--file`, `--stdin` |
| `cx help nope` | `unknown-help-topic`, 64 |
| `cx '1 2 +' --json`, `cx --json '1 2 +'`, `cx -q '1 2 +'` | accepted, 0 (G4) |
| `cx '1 2 +' --file p.txt` | `unknown-option`, 7, with the full spelling (G4) |
| `cx -- '-1 2 +'` | `1: 1`, 0 (G10) |
| `cx -e` | `unknown-option`, 7, with the `--` hint (G10) |
| `cx version` | `cx: 0.16.3`, 0 |
| `cx version --json` | `{"name": "cx", "version": "0.16.3"}`, 0 |
| `cx --json version` | `misplaced-option`, 7 (G6) |
| `cx version junk` | `extra-argument`, 64 |
| `cx verison` | `unknown-word`, 65, suggests `cx version` |
| `cx install` | `unknown-word`, 65 |
| `cx eval rpn '1 2 +' --json` | JSON stack, 0; `misplaced-option`, 7 with `POSIXLY_CORRECT` (G6) |
| `cx eval rpn -f prog.rpn --json` | program from the file, JSON, 0 |
| `cx -f prog.rpn eval rpn` | `misplaced-option`, 7 (G6) |
| `cx eval rpn -f nope.rpn` | `validation-failed`, 7, `parameter: file` |
| `cx eval rpn -f` | `missing-value`, 7 (G8) |
| `cx eval rpn --file=-x.rpn` | program from the file `-x.rpn` (G8) |
| `cx eval rpn -f a.rpn -f b.rpn` | `repeated-option`, 7 |
| `cx eval rpn -fprog.rpn`, `cx eval rpn -qh` | `invalid-short-option`, 7 (G9) |
| `cx eval rpn --stdin=true` | `unexpected-value`, 7 (G7) |
| `cx eval rpn --no-file x` | `unknown-option`, 7 (G7) |
| `cx eval rpn` | `validation-failed`, 7: no program (G1) |
| `cx eval rpn -f prog.rpn '1 2 +'`, `cx eval rpn --stdin true` | `validation-failed`, 7: two sources (G1) |
| `'1 2 +' \| cx eval rpn --stdin` | `1: 3`, 0 |
| `'9' \| cx eval rpn '1 2 +'` | `1: 3`, 0; stdin is not read (G2) |
| `cx eval rpn --max-digits 0 '1'` | `validation-failed`, 7 |
| `cx eval rpn --trace '1 2 +'` | `unknown-option`, 7 |
| `cx eval rpn '1 drop'` | empty line, 0; `{"stack": []}` with `--json` |
| `cx '3 1000000 ^'` | `limit-exceeded`, 65, with `limit`, `estimated` and the hint |
| `cx --max-digits 20000 '3 30000 ^'` | all 14314 digits, 0 |
| `cx eval infix '1 2 +'` | `syntax-error`, 65 |
| `cx eval infix '-sqrt(-1)'` | `invalid-short-option`, 7, with the `--` hint (G10) |
| `cx eval` | `incomplete-command`, 64, lists `rpn` and `infix` |
| `cx eval --help`, `cx eval rpn -q -h` | help, 0 (8.6) |
| `cx eval rpn -- --help` | program `--help`: `unknown-word`, 65 (8.6) |
| `cx eval rpn --bogus --help` | `unknown-option`, 7 (8.6) |
| `cx commands show` | `missing-argument`, 64 |
| `cx commands show ^` | the entry of `power`, 0 |
| `cx commands search hcat` | `append-cols`, 0 |
| `cx commands shwo power` | `incomplete-command`, 64, suggests `show` |
| `cx commands list --category nope` | `validation-failed`, 7, lists the categories |
| `cx --json=garbage version` | `unexpected-value`, 7 |
| `cx upgrade` | `validation-failed`, 7: needs `--plan` or `--apply` |
| `cx upgrade --plan`, `cx uninstall --plan` | the steps, nothing changes, 0 |
| `cx upgrade --apply`, no network | `release-lookup-failed`, 2; nothing changed |
| `cx doctor`, all ok / newer release or lookup failed / `cx` not on `PATH` | 0 / warning, 0 / `doctor-check-failed`, 78 |
