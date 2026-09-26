# Calculatrix CLI Specification

Status: Reviewed, 2026-09-24. Every decision is closed (section 14). Nothing
here is implemented yet.
Program: `calculatrix`, alias `cx`
Package: `calculatrix_cli` (`code/cli`)
Core dependency: `calculatrix` (`code/core`)
Framework: `modular_cli_sdk` 0.6.0 on `cli_router` 0.2.0, with the standard
plugins of the SDK (both releases to be built, section 9)
Plan: `docs/runbook-cli-stage-0.md`

This document replaces the draft of 2026-09-23. That draft routed the shortcut
through a fallback and parsed booleans with a list of names; both ideas are
dropped (section 12 records why).

## 1. Purpose

The CLI takes one input, a program as a string, and runs it. The program is
either RPN or infix, and the user always says which. It is the same language
the app runs with its keypad and the future REPL will run interactively.

The CLI has three parts:

1. **Evaluation** (`cx eval ...`): runs programs. It is the domain of the app.
2. **Encyclopedia** (`cx commands ...`): finds commands and explains what each
   one does (section 7).
3. **Maintenance** (`cx version`, `cx upgrade`, ...): keeps the installed CLI
   healthy. It is not about math.

Plus one shortcut, `cx <program>`, so that the most common use is short.

## 2. Principles

1. **One input.** A program string. Everything else is infrastructure.
2. **Declared, not guessed.** Every route, every option and every positional is
   declared in one place, with its type and its cardinality. The parser reads
   the declaration before it reads the arguments. There is no fallback, no
   second attempt after a failure, and no reinterpretation of a value.
3. **Explicit over default.** A declaration field that changes behavior
   (required, repeatable, must exist) is always written. A default value
   exists only when it is strictly needed, and then it is declared with its
   justification (section 8.4).
4. **One form.** Each thing is written one way. Where a standard exists
   (POSIX for the order of arguments, `sysexits` for exit codes), the CLI
   follows it.
5. **Reject what is ambiguous.** When an invocation could mean two things, the
   CLI rejects it and says why, with the correct form in the message.
6. **Start strict.** A form that is rejected today can become valid later
   without breaking anyone. The reverse is a breaking change. So every form
   not listed here is an error.
7. **The core owns the language.** The CLI parses arguments, reads the program
   source, calls core, and formats output. Command names, aliases, search
   terms and documentation live in the core registry, shared with the app.
8. **Modules by domain.** Each module groups one domain. The global module
   (the SDK module registered with the empty name) holds only maintenance.

## 3. Modules and routes

| Module | Domain | Routes |
|---|---|---|
| global (`''`) | maintenance of the installed CLI | `cx`, `cx help`; `cx version`, `cx doctor`, `cx upgrade`, `cx uninstall` come from the standard plugins of the SDK (8.7) |
| `eval` | evaluation of programs | `cx eval rpn`, `cx eval infix` |
| `commands` | encyclopedia of the language | `cx commands list`, `cx commands show`, `cx commands search` |
| shortcut | alias of `cx eval rpn` | `cx <program>` |

There is no `cx install`. The first installation is done by the release
script (`install.ps1`, `install.sh`), because `cx` does not exist yet at that
point. Once installed, `upgrade`, `uninstall` and `doctor` cover the life of
the installation.

### Why `eval` is its own module

The previous draft put `eval` in the global module, with `--infix` as a switch.
This draft moves it to a module and turns the mode into a route:

- **Maintenance and domain do not mix.** `version` and `eval` have nothing in
  common besides living in the same binary.
- **The mode is a route, not a flag.** `cx eval rpn` and `cx eval infix` are two
  commands with two contracts. A boolean `--infix` would make one contract
  mean two languages, and would need a value that defaults to RPN.
- **Room to grow.** A future mode is a new route in the same module, not a new
  switch that interacts with the old ones.

## 4. Invocation grammar

Every invocation has the POSIX order: the route, then the options, then the
operands.

```text
cx                                           banner
cx <program>                                 shortcut: RPN, one operand, no options
cx eval rpn [options] <program>              RPN program, inline
cx eval rpn [options] --file <path>          RPN program from a file
<source> | cx eval rpn [options] --stdin     RPN program from stdin
cx eval infix [options] <expression>         same three sources, infix
cx commands list [--category <name>]
cx commands show <name>
cx commands search <text>
cx version | doctor | help [<topic>]
cx upgrade --plan | --apply
cx uninstall --plan | --apply
```

Options of `eval rpn` and `eval infix`:

| Option | Kind | Required | Repeatable | Meaning |
|---|---|---|---|---|
| `-f, --file <path>` | value: path, must exist | no | no | read the program from a file |
| `--stdin` | flag | no | no | read the program from stdin |

Global options, declared by the SDK on every route except the shortcut:

| Option | Kind | Meaning |
|---|---|---|
| `--json` | flag | output as JSON (section 6) |
| `-q, --quiet` | flag | suppress progress messages; never the result, never errors. In `cx`, only `upgrade` and `uninstall` emit progress messages, so on the other routes it has no visible effect |
| `-h, --help` | flag | help, provided by the SDK (section 8.6) |

### Rules

- **G1. Exactly one program source.** `eval rpn` and `eval infix` take the
  program from exactly one of: the inline operand, `--file`, `--stdin`. The
  contract declares it as a constraint (`ExactlyOne`, section 8.3), so it is
  checked before the query runs.
  - None: rejected, 7, "no program: pass it inline, with --file, or with
    --stdin".
  - Two or more: rejected, 7, naming the sources found.
- **G2. Stdin is read only when asked.** Without `--stdin`, the CLI never reads
  stdin, whether or not it is a terminal. There is no check for "data waiting"
  on stdin: that check can block forever when a parent process leaves stdin
  open and never writes to it, and it would make the result depend on how the
  CLI was launched. `'1 2 +' | cx` shows the banner.
- **G3. The shortcut is a declared root route.** `cx <program>` is the route
  `<program>` at the root of the trie (section 8.1). It is resolved in the
  same single pass as every other route, with one rule: at each position a
  literal segment wins over a parameter. So `cx version` is always the route,
  and `cx commands shwo power` is an error of the `commands` module, never a
  program.
- **G4. The shortcut takes exactly one operand and no options.** It is RPN
  only, from the inline operand only. No option is accepted, not even the
  global ones. Anything else needs `cx eval rpn`:
  - `cx '1 2 +' --json` is rejected, 7: "the shortcut takes no options; use
    `cx eval rpn --json '1 2 +'`".
  - `cx 1 2 +` (unquoted, three operands) is rejected, 64: "`<program>` takes
    one operand; quote the program". Operands are never joined: in Git Bash,
    `cx 2 3 *` expands `*` to file names before the CLI sees it.
- **G5. Reserved words.** The literal children of the root are reserved:
  `eval`, `commands`, `version`, `upgrade`, `uninstall`, `doctor`, `help`. No
  RPN command, alias or search term may use one of them. The router exposes
  the set as `reservedWords`, and a CLI test checks it against the core
  registry. The set includes the routes that plugins register (8.7), since
  they are resolved at build time. Adding a root route or a plugin that
  registers one is a breaking change of the CLI, because a word that used to
  be a program becomes a route.
- **G6. POSIX order: route, options, operands.** The route is written in full
  before any option. After the route come the options, and after the options
  the operands (POSIX Utility Syntax Guidelines, guideline 9). Global options
  follow the same rule.
  - `cx eval rpn --json '1 2 +'` and `cx version --json` are valid.
  - `cx --json version` is rejected, 7: "options go after the route:
    `cx version --json`".
  - `cx eval rpn '1 2 +' --json` is rejected, 7: "options go before the
    program: `cx eval rpn --json '1 2 +'`".
  - `cx eval rpn -f p.rpn --json` is valid: both are options.
- **G7. A flag is present or absent.** A flag never takes a value: `--json` is
  the only form. `--json=true` is rejected, 7: "`--json` takes no value".
  There is no negation: `--no-json` is an unknown option. Absent always means
  no.
- **G8. A value option requires its value.** The forms are `-f p.rpn`,
  `--file p.rpn` and `--file=p.rpn`. `cx eval rpn -f` is rejected, 7: "missing
  value for -f (--file)". The next token is taken as the value only if it does
  not look like an option; a value that starts with `-` is written
  `--file=-x.rpn`.
- **G9. Short options stand alone.** A short option is one letter after one
  `-`, as its own token. `-qh` is rejected, 7: "short options stand alone:
  `-q -h`". `-fp.rpn` is rejected, 7: "the value goes apart: `-f p.rpn`".
- **G10. `--` ends the options.** It goes between the options and the
  operands; everything after it is an operand, including `--help`:
  `cx eval rpn --json -- '-x'`. `--` is grammar, not an option, so the
  shortcut accepts it: `cx -- '-x'`.
- **G11. Negative numbers are operands.** A token looks like an option only if
  it is `-` followed by a letter, `--` followed by a letter, or exactly `--`.
  So `-1 2 +`, `->ARRY` and `-[...]` are operands (`cli_router` 0.1.1 already
  does this).
- **G12. A program has tokens.** A program with no tokens (empty, or only
  whitespace) is rejected, 7: "the program is empty". It applies to the three
  sources: `cx ''`, an empty file, an empty stdin.

### Not supported, on purpose

- **Detecting infix vs RPN.** `2 -3` is two stack entries in RPN and `-1` in
  infix. The mode is always a route.
- **Joining unquoted operands** (G4).
- **A stack that persists between invocations** (`cx push 3`, then `cx +`).
  That is hidden state on disk. The live stack belongs to the REPL.
- **`--trace` and `--show-rpn`.** Not in this stage; recorded in the roadmap
  for their own design. Today they are unknown options (7).

## 5. Route catalog

| Route | Kind | Contract | What it does |
|---|---|---|---|
| `cx` | query | globals only | Logo, version, the list of routes. Never reads stdin. |
| `cx <program>` | query | one operand; no options, no globals | Same as `cx eval rpn <program>`. |
| `cx eval rpn [<program>]` | query | `--file`, `--stdin`; `ExactlyOne(program, file, stdin)` | Runs an RPN program on an empty stack and prints the stack. |
| `cx eval infix [<expression>]` | query | `--file`, `--stdin`; `ExactlyOne(expression, file, stdin)` | Evaluates an infix expression and prints the result. |
| `cx commands list` | query | `--category <name>` (value: enumeration from the registry, optional) | Lists the commands by category. |
| `cx commands show <name>` | query | one operand | The entry of one command, by name or alias. |
| `cx commands search <text>` | query | one operand | Finds commands by name, alias, HP name, search terms or description. |
| `cx version` | query | globals only | Prints the CLI version. From `VersionPlugin` (8.7). |
| `cx doctor` | query | globals only | Runs the checks contributed by the plugins (below). Changes nothing. From `DoctorPlugin` (8.7). |
| `cx upgrade` | command | `--plan` or `--apply` (SDK) | Installs the newest `cli-vX.Y.Z` release. From `InstallationPlugin` (8.7). |
| `cx uninstall` | command | `--plan` or `--apply` (SDK) | Removes the CLI. From `InstallationPlugin` (8.7). |
| `cx help [<topic>]` | query | SDK | Provided by the SDK. |

**Queries and commands.** A query changes nothing. `upgrade` and `uninstall`
change the installation, so they are SDK commands: each step is previewed,
`--plan` shows the steps and stops, `--apply` performs them. Neither flag is a
default: `cx upgrade` alone is rejected, 7. `--apply` is the confirmation;
there is no interactive prompt. Both commands come from `InstallationPlugin`,
a standard plugin of the SDK shared with `macss` and `docmd`; `cx` registers
it with its repository (`ccisnedev/calculatrix`), tag prefix (`cli-v`),
executable, alias and asset names (8.7).

**`cx doctor`.** `DoctorPlugin` runs every check contributed to the
extension point `doctor.checks`. In `cx`, all of them come from
`InstallationPlugin`. Each check ends in one of three states:

| Check | ok | warning | error |
|---|---|---|---|
| binary on `PATH` | found | | not found |
| alias `cx` | resolves to the same binary | | missing, or resolves to another binary |
| newer release | up to date | a newer `cli-v*` release exists: "run `cx upgrade --apply`" | |
| release lookup | | the lookup failed (no network, rate limit): the reason is printed | |

A warning never fails the command; it is information for a person. A failed
lookup is always reported, never skipped. Exit code: `0` when no check is an
error, `78` otherwise (section 6). The release lookup is the same code
`upgrade` uses, inside `InstallationPlugin`. JSON when no check is an error:
`{"checks": [{"name": "path", "status": "ok", "detail": "..."}]}`. When a
check is an error, the output is the single error shape of section 6 with
the id `doctor-check-failed`, exit code `78` and every check result under
`checks`:
`{"error": {"id": "doctor-check-failed", "message": "1 check failed: alias", "exitCode": 78, "checks": [...]}}`.

## 6. Output and errors

**Text (default).** HP 50g style: one line per level, level 1 at the bottom,
spaces inside matrices (runbook D12, D13).

```text
$ cx '5 [[0 -1] [1 0]]'
2: 5
1: [[0 -1] [1 0]]
```

**JSON (`--json`).** Built into the SDK: it serializes the route's
`Output.toJson()`. For `eval`:

```json
{"stack": [5, [[0, -1], [1, 0]]]}
```

- The stack is an array, level 1 last: the array has the order in which the
  values were pushed.
- A 1x1 matrix is a JSON number. Any other matrix is an array of rows, never
  flattened: the column vector `0 1 2 vector` is `[[0], [1]]`.
- Numbers are JSON numbers. `Infinity` and `NaN` never appear: a non-finite
  value is the error `non-finite`.

**Exit codes.** Six values, never mixed:

| Code | Name in the SDK | Meaning | Examples |
|---|---|---|---|
| `0` | `ExitCode.ok` | success | |
| `1` | `ExitCode.genericError` | a step of `upgrade --apply` or `uninstall --apply` failed, or the release lookup of `upgrade` failed | no network, access denied |
| `64` | `ExitCode.invalidUsage` | the invocation does not name a route (`EX_USAGE`) | unknown command, incomplete route, missing or extra operand |
| `7` | `ExitCode.validationFailed` | the route is right, an option or a value is wrong (SDK convention) | unknown or misplaced option, missing value, repeated option, two program sources, empty program, file not found, `upgrade` without `--plan` or `--apply` |
| `65` | `ExitCode.dataError` (new) | the program ran and failed (`EX_DATAERR`) | unknown RPN word, stack underflow, dimension mismatch, infix syntax error |
| `78` | `ExitCode.configError` (new) | `doctor` found an error in the installation (`EX_CONFIG`) | alias `cx` points to another binary |

A failed step carries one of the ids `release-lookup-failed`,
`download-failed`, `file-access-denied`. The run stops at that step and
reports the steps already done; it neither rolls back nor retries (runbook
D34).

`64`, `65` and `78` come from `sysexits.h` (BSD). It is a convention, not a
POSIX standard; it is used because the SDK already emits `64`. `7` is the
existing SDK convention and stays, because changing it would affect every
consumer.

**One JSON error shape (runbook D36).** With `--json`, every error, whether
from the router, the SDK, a plugin or the core, is one object under `error`
with the same three fields always present:

```json
{"error": {"id": "stack-underflow", "message": "+ needs 2 arguments, the stack has 1",
           "exitCode": 65, "token": "+", "position": 3}}
{"error": {"id": "unknown-option", "message": "unknown option '--bogus'",
           "exitCode": 7, "contract": {"...": "..."}}}
```

- `id` is always kebab-case. Usage errors use the SDK's fixed table, one id
  per router rejection kind (`unknown-command`, `unknown-option`,
  `missing-argument`, ...).
- `exitCode` repeats the process exit code.
- Other fields appear only when they apply: `token` and `position` for domain
  errors, `contract` and `details` for usage errors, `checks` for
  `doctor-check-failed` (section 5). There is no
  `isRetryable`.

**Domain errors** share exit code `65` and carry a structured id, so scripts
branch on the id and not on the code. `position` is the 1-based character
offset of the token in the program.

Ids: `unknown-word`, `stack-underflow`, `type-mismatch`, `dimension-mismatch`,
`singular-matrix`, `non-finite`, `log-undefined`, `ambiguous-power`,
`no-convergence`, `unsupported-matrix-function`, `matrix-out-of-precision-range`, `syntax-error` (infix only). The ids belong to the core; the CLI only renders
them. The semantics of `power`, the source of `log-undefined` and
`ambiguous-power`, are in the runbook (D25).

## 7. The encyclopedia: `cx commands`

This is the piece that lets people find a command and understand it. Its
content is not in the CLI: every command in the **core registry** carries its
own documentation, and the CLI and the app only render it. In the app, the same
entry opens from a long press on a key.

### Entry of a command

| Field | Example for `append-cols` |
|---|---|
| Name and aliases | `append-cols` (no aliases) |
| Search terms | `hcat`, `horzcat`, `concatenate`, `column` |
| HP 50g equivalent | none; closest `COL+` |
| Category | matrix |
| Stack effect | `A B → [A B]` |
| Preconditions | A and B have the same number of rows |
| Description | Places the columns of B to the right of A. |
| Examples | `0 1 2 vector -1 0 2 vector append-cols` gives `[[0 -1] [1 0]]` |
| Errors | `dimension-mismatch` when the row counts differ |
| See also | `append-rows`, `vector`, `transpose` |

Its pair, `append-rows`, places the rows of B below A and needs the same
number of columns; its search terms are `vcat`, `vertcat`, `concatenate`,
`row`. The names say which side grows: `append-cols` adds columns,
`append-rows` adds rows (runbook D17).

**Aliases and search terms are different things.** An alias is a word of the
language: `^` runs `power`. A search term only finds the entry: `hcat` is not
a word of the language, so `cx '... hcat'` fails with `unknown-word`, and the
error suggests `append-cols`.

**Examples are executable.** A core test runs every example and compares its
result, so an entry cannot drift from what the command does.

### Finding a command

- `cx commands search <text>` matches name, aliases, HP name, search terms and
  description: `search column` finds `append-cols` and `vector`.
- `cx commands show <alias>` resolves the alias: `show ^` shows `power`.
- `cx commands list --category matrix` lists one category. The categories are
  an enumeration taken from the registry, so an unknown category is error 7
  with the valid ones in the message.
- `--json` returns the same entries for agents and scripts.

### "Did you mean"

When a word is unknown, the error names the closest candidates. Two
vocabularies, two owners:

- **RPN words**, from the core registry (the app uses it too, so it cannot
  depend on a CLI package). Candidates are ranked by edit distance to names
  and aliases, and an exact match on a search term is a candidate too:
  `append-col` suggests `append-cols`, and `hcat` suggests `append-cols`.
- **Routes**, from the SDK catalog, through a public `suggest(word)`:
  `cx commands shwo power` suggests `show`.

A typo at the root is a program, because of the shortcut: `cx verison` runs
the RPN program `verison` and fails with `unknown-word`. The CLI adds the
route vocabulary to that error, so it suggests `cx version`. This is the one
cost of the shortcut (section 11, risk 1).

## 8. Declarative model

This section is the contract between the CLI and the packages it builds on.
All of it is a capability of `cli_router` or `modular_cli_sdk`; the CLI only
declares.

### 8.1 Resolution: a trie, one pass

Each route inserts its segments into a trie. A node has literal children (by
text), at most one parameter (`<name>`, or `[<name>]` as the last segment) and
at most one final wildcard `*`. Mounting a module grafts its trie under its
literal prefix.

When the parser reads an operand in a node:

1. If the operand is not after `--` and the node has a literal child with that
   text, it takes the literal.
2. Otherwise, if the node has a parameter, it binds the operand to it.
3. Otherwise, if the node has a wildcard, the operand goes to `rest`.
4. Otherwise, the node rejects the invocation (8.5).

The decision is local: it does not depend on what comes later, and a later
failure never moves the invocation to another branch. This is the rule HTTP
routers use for static and dynamic segments. It is not a fallback: the
shortcut is a registered route with its own node, and the rule applies to
every route alike (`commands show <name>` too).

Declaration errors fail when the CLI is built, never at run time:

- two routes with the same pattern;
- two parameters with different names at the same position;
- `[<name>]` or `*` anywhere but last;
- a literal that looks like an option;
- a positional in the contract with no matching segment in the pattern, or
  the reverse;
- one option name or abbreviation with two different shapes in the same scope;
- an abbreviation that is not exactly one letter.

### 8.2 Options: a typed schema, parsed without loss

The router knows the **shape** of each option; the SDK knows its **type**.

```dart
// cli_router 0.2.0
final class OptionSpec {
  const OptionSpec.flag(this.name, {required this.abbr, required this.repeatable})
      : takesValue = false, required = false;
  const OptionSpec.value(this.name,
      {required this.abbr, required this.required, required this.repeatable})
      : takesValue = true;
  final String name;        // long name, no dashes
  final String? abbr;       // one letter, or null (written, not omitted)
  final bool takesValue;    // fixed by the constructor
  final bool required;      // flags are never required
  final bool repeatable;
}
```

Every field that changes behavior is a required named parameter. The fields a
kind fixes (a flag takes no value and is never required) are set by its
constructor, so they cannot be contradicted. There is no `negatable`: a flag
has no negation (G7).

The parse result keeps every occurrence as it was written:

```dart
final class ParsedOption {
  final OptionSpec spec;
  final String written;   // '--file' or '-f'
  final int index;        // position in argv
  final String? value;    // null for a flag; '' when written as --file=
  final bool attached;    // the value came with '='
}
```

Grammar, all in `cli_router`:

| Form | Result |
|---|---|
| `--x v`, `--x=v`, `-x v` with `x` a value option | value `v` |
| `--x=` with `x` a value option | value `''`; the SDK type decides if it is valid |
| value option at the end, or followed by something that looks like an option | `missingValue` (7) |
| `--x` or `-x` with `x` a flag | present |
| `--x=v` with `x` a flag | `unexpectedValue` (7) |
| `-abc`, or `-fvalue` | `invalidShortOption` (7) |
| second occurrence of a non-repeatable option, by any of its names | `repeatedOption` (7) |
| option not in scope | `unknownOption` (7) |
| option in scope but not accepted by the resolved route | `unknownOption` (7), naming the route |
| option before the route is complete, or after an operand | `misplacedOption` (7) |
| required option absent | `missingRequiredOption` (7) |

`--no-x` has no special meaning: it is the option named `no-x`, which is
`unknownOption` unless a route declares that exact name.

**Scope.** At a node, the options in scope are the globals plus the options of
the routes whose literal segments are all consumed at that node.

**Detecting a misplaced option (G6) in one pass:**

- An option read at a node, followed by an operand that is a literal child of
  that node, is `misplacedOption`: `cx --json version`. The check is local:
  the node knows its literal children.
- An option read after an operand is `misplacedOption`:
  `cx eval rpn '1 2 +' --json`.
- An option not in scope at a node that has literal children, when the option
  is declared by a route under that node, is `misplacedOption`, naming the
  route: `cx eval -f p.rpn rpn`.

The lexical test for "looks like an option" is one predicate, in the router
(G11). The SDK stops using its own `startsWith('-')` checks.

### 8.3 Contracts: path apart from arguments

The pattern says where a route is. The contract says what it accepts. Each
positional in the contract names a segment of the pattern, and the build fails
if they do not match.

```dart
// modular_cli_sdk 0.6.0
final cli = ModularCli(name: 'cx', description: 'Calculatrix command line');

cli.module('', (m) {
  m.query('', BannerQuery.new, contract: CliContract.none);
});

// Standard plugins of the SDK (8.7). Each one is registered explicitly.
cli.plugin(VersionPlugin(version: cxVersion));      // version
cli.plugin(DoctorPlugin());                         // doctor, doctor.checks
cli.plugin(InstallationPlugin(                      // upgrade, uninstall,
  repository: 'ccisnedev/calculatrix',              // and its doctor checks
  tagPrefix: 'cli-v',
  executable: 'calculatrix',
  alias: 'cx',
  assets: CxAssets.byPlatform,
));

cli.module('eval', (m) {
  m.query('rpn [<program>]', EvalRpnQuery.new, contract: EvalContracts.rpn);
  m.query('infix [<expression>]', EvalInfixQuery.new, contract: EvalContracts.infix);
});

cli.module('commands', (m) {
  m.query('list', ListCommandsQuery.new, contract: CommandsContracts.list);
  m.query('show <name>', ShowCommandQuery.new, contract: CommandsContracts.show);
  m.query('search <text>', SearchCommandsQuery.new, contract: CommandsContracts.search);
});

// The shortcut: a root route that runs the target's query with a narrower
// contract. No options, and the global options are not accepted either.
cli.shortcut('<program>', target: 'eval rpn', globals: false);

abstract final class EvalContracts {
  static const file = CliParam.path('file',
      abbr: 'f', mustExist: true, required: false, repeatable: false);
  static const stdin = CliParam.flag('stdin', abbr: null, repeatable: false);

  static const rpn = CliContract(
    options: [file, stdin],
    positionals: [CliPositional.string('program')],
    constraints: [ExactlyOne(['program', 'file', 'stdin'])],
  );
  static const infix = CliContract(
    options: [file, stdin],
    positionals: [CliPositional.string('expression')],
    constraints: [ExactlyOne(['expression', 'file', 'stdin'])],
  );
}
```

The empty-program rule (G12) is not a contract field: it applies to the
program text after it is read from any of the three sources, so the eval
queries check it in `validate()` and return error 7.

Cardinality of positionals comes from the pattern:

| Segment | Operands |
|---|---|
| `<name>` | exactly one |
| `[<name>]` (last only) | zero or one |
| `*` (last only) | zero or more, in `rest` |
| none | zero; any extra operand is `extraArgument` (64) |

Value types live in the SDK: `string`, `flag`, `integer`, `number`,
`enumeration`, `path`. Each converts text to a value or fails with 7; none
turns an unexpected value into another one. Constraints between fields
(`ExactlyOne`, `MutuallyExclusive`) are declared in the contract and checked
before the query runs.

`params: null` (no contract) disappears. A route with nothing to accept
declares `CliContract.none`, because without a schema the router cannot parse
without guessing.

### 8.4 Defaults

The router applies no defaults. The SDK accepts one only as a declared object
with a value and a reason, shown in the help:

```dart
CliParam.integer('precision', ...,
    defaultValue: DeclaredDefault(12, reason: 'HP 50g STD display digits'));
```

The CLI of `cx` declares no defaults. Every option in section 4 is either
present or absent, and absent has a single meaning.

### 8.5 Rejections

`onNotFound` becomes `onReject(CliRejection)`. A rejection carries its kind,
its message, the route if one was resolved, the literal segments consumed and
the options parsed so far. The error belongs to the node that was reached; a
consumed literal never returns to the root.

Kinds that exit `64` (the invocation does not name a route):

| Situation | Kind |
|---|---|
| root, the word is no route and the root has no parameter | `unknownCommand` |
| terminal node, an operand is left over | `extraArgument` |
| non-terminal node, the operand fits no child | `incomplete` |
| end of argv at a node that needs a parameter | `missingArgument` |
| end of argv at a node with only literal children | `incomplete` |

Kinds that exit `7` (the route is right, an option is wrong): `unknownOption`,
`misplacedOption`, `missingValue`, `unexpectedValue`, `invalidShortOption`,
`repeatedOption`, `missingRequiredOption` (section 8.2).

Examples: `cx version junk` is `extraArgument`; `cx commands show` is
`missingArgument`; `cx commands shwo power` is `incomplete` in `commands`,
with the suggestion `show`; `cx eval` is `incomplete`, listing `rpn` and
`infix`.

### 8.6 Help

Help is provided by the SDK: `--help`, `-h` and the route `cx help [<topic>]`.
`cx` adds no rule of its own. The one change the SDK needs is a defect fix:
today the SDK rewrites argv before routing and does not honor `--`, so
`cx eval rpn -- --help` shows help instead of evaluating the program `--help`.
In 0.6.0 the SDK decides help after the router resolves the invocation, and
`--` is honored.

**Precedence of help.** When `-h` or `--help` is among the options read
before `--`, help wins over the rejections `incomplete`, `missingArgument`
and `missingRequiredOption`, and over the contract constraints
(`ExactlyOne`): `cx eval --help` shows the help of the `eval` module and
`cx eval rpn --help` the help of the route, both with exit 0. Help loses to
`unknownCommand`, `extraArgument` and every option error of 8.2, because
then the invocation is malformed: `cx eval rpn --bogus --help` is
`unknownOption`, 7. The router makes this possible because a rejection
carries the literals consumed and the options parsed so far (8.5).

Help is part of the SDK core, not a plugin: it depends on the
parser (`-h`, `--`), and every CLI has it.

### 8.7 Plugins

`modular_cli_sdk` 0.6.0 gets a plugin system modeled on the one of
`modular_api` (`lib/src/core/plugin.dart`), reduced to what a CLI needs today.

```dart
// modular_cli_sdk 0.6.0
final class CliPluginManifest {
  const CliPluginManifest({
    required this.id,              // 'modular_cli.version'
    required this.displayName,
    required this.version,
    required this.hostApiVersion,  // range, '>=0.1.0 <0.2.0'
    required this.requires,        // ids of other plugins; const [] if none
  });
  ...
}

abstract interface class CliPlugin {
  CliPluginManifest get manifest;
  void setup(CliPluginHost host);
}

abstract interface class CliPluginHost {
  CliHostMetadata metadata();                         // name, version of the CLI
  void registerQuery(String route, QueryFactory build, {required CliContract contract});
  void registerCommand(String route, CommandFactory build, {required CliContract contract});
  void declareExtensionPoint(CliExtensionPoint point);
  void contribute(CliExtensionContribution contribution);
  List<T> contributions<T>(String extensionPointId);
}
```

Rules:

1. **Explicit registration.** A plugin is active only if the CLI calls
   `cli.plugin(...)`. No plugin is added by the SDK on its own, including the
   standard ones. This departs from `modular_api`, where health is always on,
   on purpose: every route of the CLI is visible in its declaration.
2. **Routes of a plugin live in the global module.** They go through the same
   trie, contracts and rejections as any route (8.1 to 8.5), and they count
   as reserved words (G5).
3. **Build-time failures.** The CLI does not build when: two plugins share an
   id; a plugin registers a route that already exists; a plugin requires an
   id that is not registered; `hostApiVersion` does not include the SDK's
   plugin API version; a contribution names an extension point nobody
   declared. There is no fallback for any of them.
4. **Order.** Plugins are set up in dependency order (`requires`), then in
   registration order. A cycle is a build-time failure.
5. **Minimal host.** No middlewares, capabilities, validations or shutdown
   hooks, which `modular_api` has. Each one can be added later without
   breaking a plugin (principle 6).

The standard plugins live inside the SDK, as the official plugins of
`modular_api` live in `official_plugins.dart`:

| Plugin | Id | Routes | Extension points | Configuration (all required) |
|---|---|---|---|---|
| `VersionPlugin` | `modular_cli.version` | `version` (query) | | `version` |
| `DoctorPlugin` | `modular_cli.doctor` | `doctor` (query) | declares `doctor.checks` | none |
| `InstallationPlugin` | `modular_cli.installation` | `upgrade`, `uninstall` (commands) | contributes the checks of section 5 to `doctor.checks` | `repository`, `tagPrefix`, `executable`, `alias`, `assets` |

`InstallationPlugin` requires `modular_cli.doctor`: a CLI that registers it
without `DoctorPlugin` does not build. A CLI can contribute its own checks to
`doctor.checks` from a plugin of its own. A check is a declared object with a
name and a function that returns ok, warning or error with a detail; the
states and the exit code are those of section 5.

There is no install plugin: installation happens before the CLI exists
(section 3).

## 9. Upstream work

The design needs two releases, both breaking.

1. **`cli_router` 0.2.0.**
   - Trie resolution (8.1); `[<name>]` segments; `reservedWords`.
   - `OptionSpec`, `OptionSchema` and lossless `ParsedOption` (8.2), with the
     POSIX order (G6), flags without values (G7), short options that stand
     alone (G9) and the single "looks like an option" predicate (G11).
   - `onReject` with `CliRejection` (8.5).
   - `resolve(argv)` as a pure function for tests.
   - `CliRequest.flags` (the lossy map) is removed, not deprecated.
2. **`modular_cli_sdk` 0.6.0** on `cli_router ^0.2.0`.
   - `CliContract` with typed positionals and constraints (8.3); every
     `CliParam` field that changes behavior becomes required; `CliParam.flag`
     has no `negatable` and accepts no value.
   - `DeclaredDefault` (8.4).
   - `shortcut`.
   - Help decided after resolution, honoring `--` (8.6).
   - `suggest(word)`.
   - `ExitCode.dataError = 65` and `ExitCode.configError = 78`.
   - The global options stay: `--json`, `-q/--quiet`, `-h/--help`.
   - The plugin system and the three standard plugins (8.7):
     `VersionPlugin`, `DoctorPlugin` and `InstallationPlugin`. The SDK gains
     a dependency on HTTP (GitHub Releases) and on the file system, used only
     by `InstallationPlugin`.

There is no separate installer package: `modular_cli_installer`, planned in
runbook D20, is replaced by the standard plugins (runbook D33).

There is no opt-in "permissive" mode: that would be a default with guessed
behavior. The current pins keep consumers on 0.1.x and 0.5.x until each one
migrates.

### Migration of the known consumers

Checked read-only on 2026-09-24. The seven suites pass today against the
current packages.

| Consumer | Change needed |
|---|---|
| `macss/modular_cli_sdk` | Its own tests: null contracts, help preprocessing, `negatable`. |
| `macss/macss/code/cli` | Bump pins; contracts are already lists. Replace its own `version`, `upgrade`, `uninstall` and `doctor` with the standard plugins; its own checks become contributions to `doctor.checks`; exit code of `doctor` becomes 78. |
| `macss/docmd/code/cli` | Bump pins; check the `''` route with `--json`. Same adoption as `macss`; `doctor` stops skipping the release check when offline. |
| `macss/skillwire/code/cli` | Bump pins. |
| `macss/skillwire/code/datajack` | Bump pins. |
| `silicon-brained-machines/inquiry/code/cli` | Bump pins; check the `''` route with `--json`. |
| `ccisne-dev/linkedin_cli/code/cli` | Declare contracts for its 17 routes (it has none today); it has an option literally named `no-open`, which exact lookup keeps working. |

Across the seven there is no use of `--flag value` with booleans, `--no-x` as
negation, clusters, repeated options or `--`. Two rules can still break a
consumer: the POSIX order (an option written after an operand, or before the
route) and extra operands that used to be ignored. The procedure for each
release: run every suite, fix every failure by moving the option or removing
the operand, and update the README examples, which must follow G6.

## 10. Core fixes before the CLI reuses core

Found while testing on 2026-09-23 and 2026-09-24. They are core bugs, not CLI
design, and go in one issue in `calculatrix`:

1. **Display of large exponents.** `MatrixDisplayFormatter` trims trailing
   zeros from the exponent too: `1e20` prints as `1.00000000000e+2`
   (`matrix_display_formatter.dart:68`).
2. **Infix accepts invalid syntax.** `1 2 +` gives 3, `1()` gives 1, `√9+7`
   gives 4 (`calculatrix.dart:219`). `eval infix` must reject all three with
   `syntax-error`.
3. **Unknown words go to infix.** The old command mode hands an unknown token
   to the infix evaluator, so `2 -3` gives -1 (`calculatrix_cli.dart:151`,
   `:320-321`). In the new CLI, RPN never calls infix.
4. **Non-finite numbers crash.** `1e999` and `NaN` end with exit 255. They
   must be the domain error `non-finite` (65).

## 11. Risks

1. **A typo at the root is a program.** `cx verison` runs the program
   `verison`. This is inherent to the shortcut. Mitigation: the error suggests
   `cx version` (section 7). If this is not acceptable, the fix is to remove
   the `shortcut` line; nothing else in the design changes.
2. **Adding a root route breaks programs.** Any new root word (`cx config`)
   stops being evaluable. `reservedWords` makes it visible in a test, and it
   is released as a breaking change of the CLI.
3. **The POSIX order surprises people used to GNU tools.** Users of `git` or
   `npm`, and agents, tend to write an option at the end:
   `cx eval rpn '1 2 +' --json`. The error gives the correct form, so the
   surprise happens once. The same rule applies to the seven consumers
   (section 9).
4. **`--flag value` changes meaning** in every consumer: after 0.2.0, `value`
   is an operand. The survey found no use, but the `cli_router` README shows
   the old form and must be rewritten.
5. **`Matrix.log()` precision.** `power` with a non-integer or a matrix
   exponent relies on the principal matrix logarithm (runbook D25). Its
   precision on general matrices is not measured yet; the tests of step S4
   use the D25 table as cases.
6. **Size.** `cli_router` rewrites its dispatch and its flag parser; the SDK
   drops its help preprocessing and null contracts. The work also removes
   three different "is this an option" tests and the lossy flag map, which
   affect all seven consumers, not only `cx`.

## 12. Rejected designs

- **Fallback re-dispatch.** Route `cx <program>` from the not-found path by
  running the SDK again with `eval` in front. Rejected: it retries after a
  failure, and it captured `cx commands show`, `cx --json version` and
  `cx commands shwo power` as programs.
- **A list of boolean names per route.** Tell the parser which options take no
  value. Rejected as too little: the list was known only after the route was
  matched, and it said nothing about required or repeated options.
- **A boolean given a non-boolean value becomes true.** Rejected: it turns a
  value the user did not expect into another value.
- **`--flag=true`, `--flag=false` and `--no-flag`.** Rejected: with no defaults,
  absent already means no, so they are other ways to write nothing (G7). They
  can be added later without breaking anyone.
- **Clusters (`-qh`) and attached short values (`-fp.rpn`).** Rejected: POSIX
  says clusters should be accepted, but `cx` has two short flags and no
  consumer uses them; each form adds error cases (G9). Can be added later.
- **Free order after the route (GNU).** Rejected: two forms for the same
  invocation. POSIX order is a standard and has one form.
- **Operands before options.** Rejected: it is neither POSIX nor GNU, and `--`
  could not be combined with options.
- **Stdin read when it is not a terminal.** Rejected: the result would depend
  on how the process was launched, and the check can block (G2).
- **`cx install`.** Rejected: installation happens before `cx` exists; after
  it, nothing is left to install.
- **`upgrade` and `uninstall` as queries.** Rejected: a query changes nothing,
  by the SDK's own contract. As commands they get `--plan` and `--apply`.
- **Aliases `hcat` and `vcat`.** Rejected: they are search terms instead, so
  they find the entry without adding words to the language.
- **Auto-detecting infix.** Rejected: `2 -3` has two readings.
- **Joining unquoted operands.** Rejected: shell globbing changes the program
  before the CLI sees it.

## 13. Behavior table

Expected results of this design. Each row becomes a test of the CLI or of the
packages. The rows marked with a dagger (†) show a defect of the current
packages, measured on 2026-09-23 with `cli_router` 0.1.1 and
`modular_cli_sdk` 0.5.0.

| Invocation | Result and exit code |
|---|---|
| `cx` | banner, 0 |
| `'1 2 +' \| cx` | banner, 0; stdin is not read (G2) |
| `cx '-1 2 +'`, `cx '-1'` | evaluated, 0 |
| `cx ''`, `cx '   '` | 7, the program is empty (G12) |
| `cx [[0 -1] [1 0]] det` unquoted | `extraArgument`, 64: quote the program (G4) |
| `cx -1 2 +` unquoted | `extraArgument`, 64 (G4) |
| `cx '1 2 +' --json` | 7, the shortcut takes no options (G4) |
| `cx -- '-x'` | program `-x` (G10) |
| `cx version`, `cx help`, `cx --help` | the route or the help, never a program (G3) |
| `cx version --json` | version as JSON, 0 |
| `cx --json version` | `misplacedOption`, 7: `cx version --json` (G6) |
| `cx version junk` † | `extraArgument`, 64; today `junk` is ignored |
| `cx verison` | program `verison`, `unknown-word`, 65, suggests `cx version` |
| `cx eval rpn '1 2 +'` | prints `1: 3`, 0 |
| `cx eval rpn --json '1 2 +'` | `{"stack": [3]}`, 0 |
| `cx eval rpn '1 2 +' --json` | `misplacedOption`, 7: options go before the program (G6) |
| `cx eval rpn -f prog.rpn` | program from the file, 0 |
| `cx eval rpn -f prog.rpn --json` | program from the file, JSON, 0 |
| `cx eval rpn -f nope.rpn` | 7, file not found |
| `cx eval rpn -f empty.rpn` | 7, the program is empty (G12) |
| `cx eval rpn -f` † | `missingValue`, 7; today the path is `"true"` |
| `cx eval rpn -fprog.rpn` | `invalidShortOption`, 7: `-f prog.rpn` (G9) |
| `cx eval rpn --file=-x.rpn` | program from the file `-x.rpn` (G8) |
| `cx eval rpn --no-file x` † | `unknownOption`, 7; today it is `file=false` |
| `cx eval rpn -f a.rpn -f b.rpn` † | `repeatedOption`, 7; today the last one wins |
| `cx eval rpn -f prog.rpn '1 2 +'` | 7, two sources (G1) |
| `'1 2 +' \| cx eval rpn --stdin` | program from stdin, 0 |
| `'' \| cx eval rpn --stdin` | 7, the program is empty (G12) |
| `'9' \| cx eval rpn '1 2 +'` | prints `1: 3`, 0; stdin is not read (G2) |
| `cx eval rpn --stdin '1 2 +'` | 7, two sources (G1) |
| `cx eval rpn` | 7, no program (G1) |
| `cx eval rpn --stdin=true` | `unexpectedValue`, 7 (G7) |
| `cx eval rpn --stdin true` | 7, two sources: `true` is the program (G7) |
| `cx -f prog.rpn eval rpn` | `misplacedOption`, 7 (G6) |
| `cx eval rpn -q -h` | help, 0 |
| `cx eval rpn -qh` | `invalidShortOption`, 7: `-q -h` (G9) |
| `cx eval rpn --trace '1 2 +'` | `unknownOption`, 7 (not in this stage) |
| `cx eval rpn '1 +'` | `stack-underflow`, 65 |
| `cx eval infix '-1+2'` | prints `1: 1`, 0 |
| `cx eval infix '1 2 +'` | `syntax-error`, 65 (section 10, fix 2) |
| `cx eval` | `incomplete`, 64, lists `rpn` and `infix` |
| `cx eval --help` | help of the `eval` module, 0 |
| `cx eval rpn -- --help` † | program `--help`, `unknown-word`, 65; today help ignores `--` |
| `cx commands` | `incomplete`, 64 |
| `cx commands show` | `missingArgument`, 64 |
| `cx commands show power` | the entry, 0 |
| `cx commands show ^` | the entry of `power`, 0 |
| `cx commands search hcat` | the entry of `append-cols`, 0 |
| `cx commands shwo power` | `incomplete`, 64, suggests `show` |
| `cx commands list --category nope` | 7, lists the valid categories |
| `cx --json=garbage version` † | 7; today it exits 0 |
| `cx upgrade` | 7, needs `--plan` or `--apply` |
| `cx upgrade --plan` | the steps, nothing changes, 0 |
| `cx uninstall --apply` | removes the CLI, 0 |
| `cx upgrade --apply`, no network | `release-lookup-failed`, 1; nothing changed |
| `cx eval rpn --help` | help of the route, 0 (8.6) |
| `cx commands show --help` | help of the route, 0 (8.6) |
| `cx eval rpn --bogus --help` | `unknownOption`, 7 (8.6) |
| `cx doctor`, all checks ok | 0 |
| `cx doctor`, newer release or no network | warning printed, 0 |
| `cx doctor`, alias `cx` points elsewhere | error printed, 78 |
| `cx install` | program `install`, `unknown-word`, 65 |
| `cx 2 3 *` in Git Bash | the shell expands `*`; the CLI sees several operands and rejects them, 64 (G4) |

## 14. Decisions of the review of 2026-09-24

Every question of the draft is closed. The user decided each one; the runbook
records the ones that affect the whole stage (D25 to D38).

| # | Topic | Decision |
|---|---|---|
| R1 | `upgrade`, `uninstall` | SDK commands with `--plan` / `--apply`, no default, no prompt; they come from `InstallationPlugin` (R18). Corrects runbook D3 and D15. |
| R2 | Stdin | Read only with `--stdin`; `'1 2 +' \| cx` shows the banner (G2). |
| R3 | Shortcut options | None, not even globals (G4). |
| R4 | Empty program | Error 7 from any source (G12). |
| R5 | Order | POSIX: route, options, operands (G6). |
| R6 | Flags | Presence only; no `=value`, no negation (G7). Can be extended later. |
| R7 | Short options | Stand alone; no clusters, no attached values (G9). Can be extended later. |
| R8 | Help | Provided by the SDK; only the `--` defect is fixed (8.6). |
| R9 | Domain exit code | `65` (`EX_DATAERR`), `ExitCode.dataError` in the SDK. |
| R10 | `--quiet` | Stays a global of the SDK: suppresses progress messages, never results or errors. |
| R11 | `cx install` | Does not exist. The release script installs. |
| R12 | Aliases of `append-cols`, `append-rows` | None. `hcat`, `vcat` and related words are search terms. |
| R13 | `power` | `B^Y = exp(Y · log B)`, with the full table in runbook D25. |
| R14 | `--trace`, `--show-rpn` | Not in this stage; in the roadmap. |
| R15 | `CliRequest.flags` | Removed in `cli_router` 0.2.0. |
| R16 | JSON of `eval` | `{"stack": [...]}`, level 1 last, 1x1 as a number, other matrices as rows. |
| R17 | `doctor` | Local checks plus the newer-release check; states ok, warning, error; a failed lookup is a warning, never skipped; exit 78 on any error, with the error `doctor-check-failed` carrying every check result (section 5). |
| R18 | Standard routes | `version`, `doctor`, `upgrade` and `uninstall` come from standard plugins inside `modular_cli_sdk` (8.7), registered explicitly; `doctor` gathers checks through the extension point `doctor.checks`. There is no `modular_cli_installer` package. |
| R19 | `power`, closing the table | Order of checks by kinds; `i [[1 0] [0 2]] ^` is `ambiguous-power`; a non-square exponent is `dimension-mismatch` with any base (runbook D34). |
| R20 | Help precedence | Wins over an incomplete route, a missing argument or option, and the constraints; loses to malformed invocations (8.6). |
| R21 | Failure of `--apply` | Exit `1` with a structured id; stop at the failed step, no rollback, no retry (section 6). |
| R22 | `no-convergence` | An iterative method (matrix exponential, square root, logarithm) that does not reach its tolerance within its cap raises `no-convergence` (65); it never returns the unconverged value (runbook D35). |
| R23 | `unsupported-matrix-function` | `exp`, `log`, `sqrt` and a non-integer real power accept a scalar, the complex form, a diagonal, a symmetric or a 2x2 matrix; any other matrix raises `unsupported-matrix-function` (65), never an approximation (runbook D37). |
| R24 | `matrix-out-of-precision-range` | `exp`, `log`, `sqrt` and a non-integer real power accept only matrices whose nonzero entries and nonzero eigenvalues have magnitudes between `1e-150` and `1e150`; outside that range, or when an eigenvalue or a nonzero entry of the result falls outside it (`exp(-1000)`, `exp(710)`), they raise `matrix-out-of-precision-range` (65). Inside it the normwise relative error is at most `1e4 * kappa * u`, with `kappa` the relative condition number of the function at the matrix and `u = 2^-53` (about `1e-12` for a well conditioned matrix); a zero result and `sqrt` of a singular matrix get the absolute bounds of runbook D38). |
