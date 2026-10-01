// Tests for runbook stage S2 (docs/runbook-cli-stage-0.md), covering every
// row of docs/spec/calculatrix_cli.md section 13 that S2 delivers.
//
// Excluded by the runbook's own scope: the version/doctor/upgrade/uninstall
// rows, now covered by stage S3 in installation_test.dart, and the
// commands/domain-error-id/"cx verison" suggestion rows (S4). A handful of
// grammar rows here necessarily surface a domain error from the core
// evaluator (an ill-formed RPN or infix program); those are asserted only
// on exit code 65, never on the specific error id, since the id catalog
// itself is S4's concern. See the PR's "Open points".
import 'dart:convert';
import 'dart:io';

import 'package:calculatrix_cli/calculatrix_cli.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:test/test.dart';

import 'support/memory_sink.dart';

void main() {
  late MemorySink out;
  late MemorySink err;
  late Directory tempDir;

  setUp(() {
    out = MemorySink();
    err = MemorySink();
    tempDir = Directory.systemTemp.createTempSync('calculatrix_cli_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  // User decision (2026-09-29): cx follows GNU order by default (an option
  // may follow an operand; cli_router permutes it in front before the
  // strict grammar runs), like macss, inquiry and skillwire. The production
  // entry point (bin/calculatrix_cli.dart) passes nothing, so cli_router
  // reads POSIXLY_CORRECT from the real process environment; here
  // [environment] defaults to an empty map (equivalent to a real
  // environment with no POSIXLY_CORRECT set), so a test gets GNU order
  // unless it opts into strict POSIX explicitly with
  // environment: {'POSIXLY_CORRECT': '1'}.
  Future<int> run(
    List<String> args, {
    StdinReader? readStdin,
    Map<String, String> environment = const {},
  }) {
    final cli = buildCalculatrixCli(readStdin: readStdin ?? () => '');
    return cli.run(args, stdout: out, stderr: err, environment: environment);
  }

  group('banner (G2, G3)', () {
    test('cx prints a banner naming the program cx and exits 0', () async {
      final code = await run([]);
      expect(code, ExitCode.ok);
      expect(out.output, contains('cx'));
      // The executable is `cx`; there is no `calculatrix` command name
      // anywhere (issue #22). "Calculatrix" the product name, capitalized,
      // in prose is fine and does not trip this: the lowercase word
      // "calculatrix" is what would read as a command name.
      expect(out.output, isNot(contains('calculatrix')));
    });

    test('cx ignores stdin and still prints the banner (G2)', () async {
      final code = await run(
        [],
        readStdin: () => fail('stdin must not be read'),
      );
      expect(code, ExitCode.ok);
      expect(out.output, contains('cx'));
      expect(out.output, isNot(contains('calculatrix')));
    });

    test('the CLI is named cx, with no alias, in its own metadata', () {
      final cli = buildCalculatrixCli();
      expect(cli.hostMetadata?.name, 'cx');
    });

    test('cx help prints help and exits 0, not a program (G3)', () async {
      final code = await run(['help']);
      expect(code, ExitCode.ok);
    });

    test('cx --help prints help and exits 0, not a program (G3)', () async {
      final code = await run(['--help']);
      expect(code, ExitCode.ok);
    });
  });

  group('usage lines name cx (issue #22 acceptance item 3, PR #23 review)', () {
    test('cx --help prints a Usage: line naming cx', () async {
      final code = await run(['--help']);
      expect(code, ExitCode.ok);
      expect(out.output, contains('Usage: cx'));
    });

    test(
      'an option error under eval infix prints a Usage: line naming cx',
      () async {
        final code = await run(['eval', 'infix', '--bogus']);
        expect(code, ExitCode.validationFailed);
        expect(err.output, contains('Usage: cx eval infix'));
      },
    );
  });

  group('cx <program> shortcut', () {
    test("cx '-1 2 +' evaluates and exits 0", () async {
      final code = await run(['-1 2 +']);
      expect(code, ExitCode.ok);
      expect(out.output, contains('1: 1'));
    });

    test("cx '[[0 -1][1 0]] 2 ^' accepts adjacent rows (issue #29)", () async {
      final code = await run(['[[0 -1][1 0]] 2 ^']);
      expect(code, ExitCode.ok);
      expect(out.output, contains('1: [[-1 0] [0 -1]]'));
    });

    test("cx '-1' evaluates and exits 0", () async {
      final code = await run(['-1']);
      expect(code, ExitCode.ok);
      expect(out.output, contains('1: -1'));
    });

    test("cx '' rejects an empty program (G12)", () async {
      final code = await run(['']);
      expect(code, ExitCode.validationFailed);
    });

    test("cx '   ' rejects a blank program (G12)", () async {
      final code = await run(['   ']);
      expect(code, ExitCode.validationFailed);
    });

    test('an unquoted multi-token program is extraArgument, 64 (G4)', () async {
      final code = await run(['[[0', '-1]', '[1', '0]]', 'det']);
      expect(code, ExitCode.invalidUsage);
    });

    test('cx -1 2 + unquoted is extraArgument, 64 (G4)', () async {
      final code = await run(['-1', '2', '+']);
      expect(code, ExitCode.invalidUsage);
    });

    test(
      "cx '1 2 +' --json is rejected: the shortcut takes no options (G4)",
      () async {
        final code = await run(['1 2 +', '--json']);
        expect(code, ExitCode.validationFailed);
      },
    );

    test("cx -- '-x' treats -x as the program, not an option (G10)", () async {
      final code = await run(['--', '-x']);
      // The grammar layer must accept "-x" as the operand rather than
      // reject it as an unknown option; what core then makes of the
      // program "-x" is a domain-error-id concern deferred to S4.
      expect(code, ExitCode.dataError);
    });
  });

  group('eval rpn: sources (G1, G2)', () {
    test("cx eval rpn '1 2 +' prints 1: 3", () async {
      final code = await run(['eval', 'rpn', '1 2 +']);
      expect(code, ExitCode.ok);
      expect(out.output, contains('1: 3'));
    });

    test('cx eval rpn --json prints the JSON stack', () async {
      final code = await run(['eval', 'rpn', '--json', '1 2 +']);
      expect(code, ExitCode.ok);
      expect(jsonDecode(out.output), {
        'stack': [
          {'level': 1, 'exact': true, 'value': '3'},
        ],
      });
    });

    test('cx eval rpn -f reads the program from a file', () async {
      final file = File('${tempDir.path}/prog.rpn')..writeAsStringSync('1 2 +');
      final code = await run(['eval', 'rpn', '-f', file.path]);
      expect(code, ExitCode.ok);
      expect(out.output, contains('1: 3'));
    });

    test(
      'cx eval rpn -f --json reads the program from a file as JSON',
      () async {
        final file = File('${tempDir.path}/prog.rpn')
          ..writeAsStringSync('1 2 +');
        final code = await run(['eval', 'rpn', '-f', file.path, '--json']);
        expect(code, ExitCode.ok);
        expect(jsonDecode(out.output), {
          'stack': [
            {'level': 1, 'exact': true, 'value': '3'},
          ],
        });
      },
    );

    test('cx eval rpn -f nope.rpn fails: file not found', () async {
      final code = await run(['eval', 'rpn', '-f', '${tempDir.path}/nope.rpn']);
      expect(code, ExitCode.validationFailed);
    });

    test('cx eval rpn -f empty.rpn rejects an empty program (G12)', () async {
      final file = File('${tempDir.path}/empty.rpn')..writeAsStringSync('   ');
      final code = await run(['eval', 'rpn', '-f', file.path]);
      expect(code, ExitCode.validationFailed);
    });

    test(
      'cx eval rpn -f prog.rpn PROGRAM is rejected: two sources (G1)',
      () async {
        final file = File('${tempDir.path}/prog.rpn')
          ..writeAsStringSync('1 2 +');
        final code = await run(['eval', 'rpn', '-f', file.path, '1 2 +']);
        expect(code, ExitCode.validationFailed);
      },
    );

    test('cx eval rpn --stdin reads the program from stdin', () async {
      final code = await run([
        'eval',
        'rpn',
        '--stdin',
      ], readStdin: () => '1 2 +');
      expect(code, ExitCode.ok);
      expect(out.output, contains('1: 3'));
    });

    test('cx eval rpn --stdin rejects an empty program (G12)', () async {
      final code = await run(['eval', 'rpn', '--stdin'], readStdin: () => '');
      expect(code, ExitCode.validationFailed);
    });

    test('cx eval rpn PROGRAM ignores stdin (G2)', () async {
      final code = await run([
        'eval',
        'rpn',
        '1 2 +',
      ], readStdin: () => fail('stdin must not be read'));
      expect(code, ExitCode.ok);
      expect(out.output, contains('1: 3'));
    });

    test('cx eval rpn --stdin PROGRAM is rejected: two sources (G1)', () async {
      final code = await run(['eval', 'rpn', '--stdin', '1 2 +']);
      expect(code, ExitCode.validationFailed);
    });

    test('cx eval rpn with no source is rejected: no program (G1)', () async {
      final code = await run(['eval', 'rpn']);
      expect(code, ExitCode.validationFailed);
    });
  });

  // Mirrors "eval rpn: sources" above: `eval infix` shares its options and
  // its ExactlyOne(expression, file, stdin) constraint with `eval rpn`
  // (EvalContracts, eval_support.dart's resolveProgramSource), so every
  // source and rejection case there has an infix counterpart here too.
  group('eval infix: sources (G1, G2)', () {
    test(
      'cx eval infix -f expr.txt reads the expression from a file',
      () async {
        final file = File('${tempDir.path}/expr.txt')
          ..writeAsStringSync('2+3*4');
        final code = await run(['eval', 'infix', '-f', file.path]);
        expect(code, ExitCode.ok);
        expect(out.output, contains('1: 14'));
      },
    );

    test('cx eval infix --stdin reads the expression from stdin', () async {
      final code = await run([
        'eval',
        'infix',
        '--stdin',
      ], readStdin: () => '2+3*4');
      expect(code, ExitCode.ok);
      expect(out.output, contains('1: 14'));
    });

    test('cx eval infix with no source is rejected: no program (G1)', () async {
      final code = await run(['eval', 'infix']);
      expect(code, ExitCode.validationFailed);
    });

    test(
      'cx eval infix -f expr.txt EXPRESSION is rejected: two sources (G1)',
      () async {
        final file = File('${tempDir.path}/expr.txt')
          ..writeAsStringSync('2+3*4');
        final code = await run(['eval', 'infix', '-f', file.path, '2+3*4']);
        expect(code, ExitCode.validationFailed);
      },
    );

    test(
      'cx eval infix -f expr.txt --stdin is rejected: two sources (G1)',
      () async {
        final file = File('${tempDir.path}/expr.txt')
          ..writeAsStringSync('2+3*4');
        final code = await run(['eval', 'infix', '-f', file.path, '--stdin']);
        expect(code, ExitCode.validationFailed);
      },
    );

    test('cx eval infix -f empty.txt rejects an empty program (G12)', () async {
      final file = File('${tempDir.path}/empty.txt')..writeAsStringSync('   ');
      final code = await run(['eval', 'infix', '-f', file.path]);
      expect(code, ExitCode.validationFailed);
    });

    test('cx eval infix --stdin rejects an empty program (G12)', () async {
      final code = await run(['eval', 'infix', '--stdin'], readStdin: () => '');
      expect(code, ExitCode.validationFailed);
    });
  });

  group('eval rpn: option grammar (G6, G7, G8, G9)', () {
    // Moved to explicit strict-mode environment per the 2026-09-29 GNU-order
    // decision: under the default (GNU order), this same invocation is
    // accepted instead (see the two tests below), so this one is only
    // misplacedOption once POSIXLY_CORRECT is set.
    test('cx eval rpn PROGRAM --json is misplacedOption, 7 (G6)', () async {
      final code = await run(
        ['eval', 'rpn', '1 2 +', '--json'],
        environment: const {'POSIXLY_CORRECT': '1'},
      );
      expect(code, ExitCode.validationFailed);
    });

    // User decision (2026-09-29): cx follows GNU order by default (options
    // may follow operands), like macss, inquiry and skillwire; only
    // POSIXLY_CORRECT (read from the real environment) restores strict
    // POSIX order. Under the default (no POSIXLY_CORRECT, environment: {}),
    // "--json" after the program and before it are equivalent: cli_router's
    // GNU permutation moves the option in front of the operand before the
    // strict grammar runs.
    test("cx eval rpn --json '1 2 +' and cx eval rpn '1 2 +' --json are "
        'identical under GNU order (default, no POSIXLY_CORRECT)', () async {
      final first = await run([
        'eval',
        'rpn',
        '--json',
        '1 2 +',
      ], environment: const {});
      final firstOut = out.output;
      final firstErr = err.output;

      out = MemorySink();
      err = MemorySink();
      final second = await run([
        'eval',
        'rpn',
        '1 2 +',
        '--json',
      ], environment: const {});

      expect(second, first);
      expect(out.output, firstOut);
      expect(err.output, firstErr);
      expect(first, ExitCode.ok);
      expect(jsonDecode(firstOut), {
        'stack': [
          {'level': 1, 'exact': true, 'value': '3'},
        ],
      });
    });

    // Same invocation as above, but with POSIXLY_CORRECT set: GNU
    // permutation is off, so the option after the operand is misplaced.
    // The offending option is `--json` itself, so it was never among the
    // options "successfully read before the rejection"; the SDK's jsonMode
    // detection (rejection.options.any((o) => o.spec.name == 'json')) is
    // therefore false here, and the error is rendered as text, not JSON:
    // "Error: <message> [<id>]".
    test("cx eval rpn '1 2 +' --json is misplaced-option, 7, under strict "
        'POSIX (POSIXLY_CORRECT)', () async {
      final code = await run(
        ['eval', 'rpn', '1 2 +', '--json'],
        environment: const {'POSIXLY_CORRECT': '1'},
      );
      expect(code, ExitCode.validationFailed);
      expect(err.output, contains('[misplaced-option]'));
      expect(err.output, contains('an option cannot follow an operand'));
    });

    test('cx eval rpn -f (missing value) is rejected, 7', () async {
      final code = await run(['eval', 'rpn', '-f']);
      expect(code, ExitCode.validationFailed);
    });

    test('cx eval rpn -fprog.rpn is invalidShortOption, 7 (G9)', () async {
      final code = await run(['eval', 'rpn', '-fprog.rpn']);
      expect(code, ExitCode.validationFailed);
    });

    test(
      'cx eval rpn --file=-x.rpn reads a dash-prefixed filename (G8)',
      () async {
        final previousCwd = Directory.current;
        Directory.current = tempDir;
        try {
          File('-x.rpn').writeAsStringSync('1 2 +');
          final code = await run(['eval', 'rpn', '--file=-x.rpn']);
          expect(code, ExitCode.ok);
          expect(out.output, contains('1: 3'));
        } finally {
          Directory.current = previousCwd;
        }
      },
    );

    test('cx eval rpn --no-file x is rejected, 7', () async {
      final code = await run(['eval', 'rpn', '--no-file', 'x']);
      expect(code, ExitCode.validationFailed);
    });

    test('cx eval rpn -f a.rpn -f b.rpn is rejected, 7', () async {
      final a = File('${tempDir.path}/a.rpn')..writeAsStringSync('1 2 +');
      final b = File('${tempDir.path}/b.rpn')..writeAsStringSync('1 2 +');
      final code = await run(['eval', 'rpn', '-f', a.path, '-f', b.path]);
      expect(code, ExitCode.validationFailed);
    });

    test('cx eval rpn --stdin=true is unexpectedValue, 7 (G7)', () async {
      final code = await run(['eval', 'rpn', '--stdin=true']);
      expect(code, ExitCode.validationFailed);
    });

    test(
      'cx eval rpn --stdin true: true becomes the program, two sources (G7)',
      () async {
        final code = await run(['eval', 'rpn', '--stdin', 'true']);
        expect(code, ExitCode.validationFailed);
      },
    );

    // An option written before the route word that declares it is always
    // misplacedOption: GNU permutation only ever moves an option earlier
    // relative to operands, never across an unresolved route boundary, so
    // this stays rejected the same way under either ordering. Kept
    // explicit here (strict mode) since it is one of the two tests
    // labeled G6 (the other is above), per the 2026-09-29 GNU-order
    // decision, even though its outcome does not depend on it.
    test('cx -f prog.rpn eval rpn is misplacedOption, 7 (G6)', () async {
      final code = await run(
        ['-f', 'prog.rpn', 'eval', 'rpn'],
        environment: const {'POSIXLY_CORRECT': '1'},
      );
      expect(code, ExitCode.validationFailed);
    });

    test('cx eval rpn -q -h prints help, 0', () async {
      final code = await run(['eval', 'rpn', '-q', '-h']);
      expect(code, ExitCode.ok);
    });

    test('cx eval rpn -qh is invalidShortOption, 7 (G9)', () async {
      final code = await run(['eval', 'rpn', '-qh']);
      expect(code, ExitCode.validationFailed);
    });

    test('cx eval rpn --trace PROGRAM is unknownOption, 7', () async {
      final code = await run(['eval', 'rpn', '--trace', '1 2 +']);
      expect(code, ExitCode.validationFailed);
    });
  });

  group('eval rpn and eval infix: evaluation', () {
    test("cx eval rpn '1 +' fails as a domain error, 65", () async {
      final code = await run(['eval', 'rpn', '1 +']);
      // The specific error id (stack-underflow) is a domain-error-id
      // concern deferred to S4; here only the exit code is asserted.
      expect(code, ExitCode.dataError);
    });

    test("cx eval infix '-1+2' prints 1: 1", () async {
      final code = await run(['eval', 'infix', '-1+2']);
      expect(code, ExitCode.ok);
      expect(out.output, contains('1: 1'));
    });

    test("cx eval infix '1 2 +' fails as a domain error, 65", () async {
      final code = await run(['eval', 'infix', '1 2 +']);
      expect(code, ExitCode.dataError);
    });

    test('cx eval rpn -- --help: --help becomes the program (G10)', () async {
      final code = await run(['eval', 'rpn', '--', '--help']);
      expect(code, ExitCode.dataError);
    });
  });

  group('eval output: display formatter and whole stack (D45, D47)', () {
    test(
      "cx '~[[1 2] [3 4]] inverse' prints 1: ~[[-2 1] [1.5 -0.5]]",
      () async {
        // An approximate value carries the mark once, in front (D54).
        final code = await run(['~[[1 2] [3 4]] inverse']);
        expect(code, ExitCode.ok);
        expect(out.output, '1: ~[[-2 1] [1.5 -0.5]]\n');
      },
    );

    test('--json keeps the full double the text rounds', () async {
      final code = await run(['eval', 'rpn', '--json', '[[1 2] [3 4]] -1 ^']);
      expect(code, ExitCode.ok);
      final decoded = jsonDecode(out.output) as Map<String, dynamic>;
      final level = (decoded['stack'] as List).single as Map;
      expect(level['level'], 1);
      expect(((level['value'] as List).first as List).first, isNot(-2));
    });

    test("cx eval rpn '~2 3 /' prints 12 significant digits", () async {
      final code = await run(['eval', 'rpn', '~2 3 /']);
      expect(code, ExitCode.ok);
      expect(out.output, '1: ~0.666666666667\n');
    });

    test("cx '5 [[0 -1] [1 0]]' prints every level, level 1 last", () async {
      final code = await run(['5 [[0 -1] [1 0]]']);
      expect(code, ExitCode.ok);
      expect(out.output, '2: 5\n1: [[0 -1] [1 0]]\n');
    });

    test(
      'cx eval rpn --json gives each level explicitly, in print order',
      () async {
        final code = await run(['eval', 'rpn', '--json', '5 7 9']);
        expect(code, ExitCode.ok);
        expect(jsonDecode(out.output), {
          'stack': [
            {'level': 3, 'exact': true, 'value': '5'},
            {'level': 2, 'exact': true, 'value': '7'},
            {'level': 1, 'exact': true, 'value': '9'},
          ],
        });
      },
    );

    test("cx eval rpn '1 drop' leaves an empty stack: no level, 0", () async {
      final code = await run(['eval', 'rpn', '1 drop']);
      expect(code, ExitCode.ok);
      expect(out.output.trim(), isEmpty);
      expect(err.output, isEmpty);
    });

    test("cx eval rpn --json '1 drop' is an empty stack array", () async {
      final code = await run(['eval', 'rpn', '--json', '1 drop']);
      expect(code, ExitCode.ok);
      expect(jsonDecode(out.output), {'stack': <Object>[]});
    });

    test('cx eval infix --json gives its one value as level 1', () async {
      final code = await run(['eval', 'infix', '--json', '1+2']);
      expect(code, ExitCode.ok);
      expect(jsonDecode(out.output), {
        'stack': [
          {'level': 1, 'exact': true, 'value': '3'},
        ],
      });
    });

    test("cx eval rpn --json '~1e300 1e300 *' is non-finite, 65", () async {
      final code = await run(['eval', 'rpn', '--json', '~1e300 1e300 *']);
      expect(code, ExitCode.dataError);
      final error =
          (jsonDecode(out.output + err.output) as Map)['error'] as Map;
      expect(error['id'], 'non-finite');
      expect(error['details'], {'token': '*', 'position': 14});
    });
  });

  group('infix name errors in JSON (issue #51, AC2)', () {
    // The error envelope goes to stderr, never stdout
    // (`_renderRecordedError` in modular_cli_sdk writes only to `err`; see
    // the equivalent assertion in commands_cli_test.dart).
    test('cx eval infix "sqrt(7)" --json carries details.name, which '
        'error.message alone does not let a caller recover', () async {
      final code = await run(['eval', 'infix', '--json', 'sqrt(7)']);
      expect(code, ExitCode.dataError);
      final decoded = jsonDecode(err.output) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>;
      final details = error['details'] as Map<String, dynamic>;
      expect(details['name'], 'sqrt');
      expect(error['message'], contains('cx eval rpn "7 sqrt"'));
    });

    test('cx eval infix "sqrt(1+2)" never suggests a command that would '
        'itself fail (issue #51, AC2): "cx eval rpn \\"1+2 sqrt\\"" is two '
        'tokens, the second of which is unknown-word', () async {
      final code = await run(['eval', 'infix', '--json', 'sqrt(1+2)']);
      expect(code, ExitCode.dataError);
      final decoded = jsonDecode(err.output) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>;
      expect(error['message'], isNot(contains('cx eval rpn')));
    });

    test('cx eval infix "sqrt (7)" (space before the call) never suggests a '
        'command that would itself underflow (issue #51, AC2)', () async {
      final code = await run(['eval', 'infix', '--json', 'sqrt (7)']);
      expect(code, ExitCode.dataError);
      final decoded = jsonDecode(err.output) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>;
      expect(error['message'], isNot(contains('cx eval rpn')));
    });

    test('cx eval infix "frobenius-norm(7)" names the whole hyphenated word, '
        'not just "frobenius" (issue #51, AC2)', () async {
      final code = await run(['eval', 'infix', '--json', 'frobenius-norm(7)']);
      expect(code, ExitCode.dataError);
      final decoded = jsonDecode(err.output) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>;
      final details = error['details'] as Map<String, dynamic>;
      expect(details['name'], 'frobenius-norm');
      expect(error['message'], contains('cx eval rpn "7 frobenius-norm"'));
    });

    test('cx "3^-2" (shortcut) hints at eval infix instead of a plain '
        'unknown-word (issue #51, AC3)', () async {
      final code = await run(['3^-2']);
      expect(code, ExitCode.dataError);
      expect(err.output, contains('this looks like an infix expression'));
    });

    test('cx eval rpn "1+.5" hints at eval infix instead of a plain '
        'unknown-word (issue #51, AC3)', () async {
      final code = await run(['eval', 'rpn', '1+.5']);
      expect(code, ExitCode.dataError);
      expect(err.output, contains('this looks like an infix expression'));
    });
  });

  group('eval module and help precedence (8.6)', () {
    test('cx eval alone is incomplete, 64', () async {
      final code = await run(['eval']);
      expect(code, ExitCode.invalidUsage);
    });

    test('cx eval --help prints the eval module help, 0', () async {
      final code = await run(['eval', '--help']);
      expect(code, ExitCode.ok);
    });

    test('cx eval rpn --help prints the route help, 0', () async {
      final code = await run(['eval', 'rpn', '--help']);
      expect(code, ExitCode.ok);
    });

    test(
      'cx eval rpn --bogus --help is unknownOption, 7: badly typed beats --help',
      () async {
        final code = await run(['eval', 'rpn', '--bogus', '--help']);
        expect(code, ExitCode.validationFailed);
      },
    );
  });

  // Every non-trivial numeric result below is independently checked against
  // Giac (WSL Ubuntu, giac 1.9.0), the black-box numerical reference. The
  // exact Giac input is test/fixtures/giac_reference.giac; it was run as:
  //   wsl -d Ubuntu -- bash -c "giac < '/mnt/c/.../giac_reference.giac'" |
  //     tr -d '\000'
  // and produced (Digits:=20, so 20 significant decimal digits):
  //   div    (2/3)                       -> 0.66666666666666666666
  //   sqrt   (sqrt(2))                   -> 1.4142135623730950488
  //   pow    (2^0.5)                     -> 1.4142135623730950488
  //   matmul ([[1,2],[3,4]]*[[5,6],[7,8]]) -> [[19,22],[43,50]] (exact)
  //   neg    (1-2)                       -> -1.0000000000000000000 (exact)
  //
  // Matrix's own `/` operator only supports a scalar, i.e. 1x1, denominator
  // (matrix-by-matrix division throws typeMismatch), so a Giac-checked
  // matrix inverse case built through `/` cannot be built here. `inverse`
  // and `inv` are now registered RPN words (issue #35, defined as `-1
  // power`), but that word and its Giac cross-check belong with the rest
  // of the S4 commands catalog coverage, not this Giac fixture group.
  group('Giac-verified numeric results (non-trivial)', () {
    // Relative-tolerance comparison against a Giac-derived expected value,
    // matching the CLI's own JSON number (an int or a double per
    // eval_support.dart's _jsonNumber).
    void expectNearGiac(num actual, double expected) {
      final double diff = (actual.toDouble() - expected).abs();
      final double scale = expected.abs() == 0 ? 1.0 : expected.abs();
      expect(
        diff / scale,
        lessThanOrEqualTo(1e-12),
        reason: 'actual=$actual expected=$expected (giac)',
      );
    }

    void expectMatrixNearGiac(Object? actual, List<List<double>> expected) {
      final rows = actual! as List;
      expect(rows.length, expected.length);
      for (var r = 0; r < expected.length; r++) {
        final row = rows[r] as List;
        expect(row.length, expected[r].length);
        for (var c = 0; c < expected[r].length; c++) {
          expectNearGiac(row[c] as num, expected[r][c]);
        }
      }
    }

    // 2/3: non-terminating division. Giac: evalf(2/3) = 0.666...6 (20 d.p).
    test("cx eval rpn '~2 3 /' matches Giac's 2/3 within 1e-12", () async {
      final code = await run(['eval', 'rpn', '--json', '~2 3 /']);
      expect(code, ExitCode.ok);
      final decoded = jsonDecode(out.output) as Map<String, dynamic>;
      final stack = decoded['stack'] as List;
      expectNearGiac(
        (stack.single as Map)['value'] as num,
        0.66666666666666666666,
      );
    });

    test("cx eval infix '~2/3' matches Giac's 2/3 within 1e-12", () async {
      final code = await run(['eval', 'infix', '--json', '~2/3']);
      expect(code, ExitCode.ok);
      final decoded = jsonDecode(out.output) as Map<String, dynamic>;
      final stack = decoded['stack'] as List;
      expectNearGiac(
        (stack.single as Map)['value'] as num,
        0.66666666666666666666,
      );
    });

    // sqrt(2). Giac: evalf(sqrt(2)) = 1.4142135623730950488.
    test("cx eval rpn '2 √' matches Giac's sqrt(2) within 1e-12", () async {
      final code = await run(['eval', 'rpn', '--json', '2 √']);
      expect(code, ExitCode.ok);
      final decoded = jsonDecode(out.output) as Map<String, dynamic>;
      final stack = decoded['stack'] as List;
      expectNearGiac(
        (stack.single as Map)['value'] as num,
        1.4142135623730950488,
      );
    });

    test("cx eval infix '√2' matches Giac's sqrt(2) within 1e-12", () async {
      final code = await run(['eval', 'infix', '--json', '√2']);
      expect(code, ExitCode.ok);
      final decoded = jsonDecode(out.output) as Map<String, dynamic>;
      final stack = decoded['stack'] as List;
      expectNearGiac(
        (stack.single as Map)['value'] as num,
        1.4142135623730950488,
      );
    });

    // 2^0.5: non-integer power, same value as sqrt(2) by construction.
    // Giac: evalf(2^0.5) = 1.4142135623730950488.
    test("cx eval rpn '2 0.5 ^' matches Giac's 2^0.5 within 1e-12", () async {
      final code = await run(['eval', 'rpn', '--json', '2 0.5 ^']);
      expect(code, ExitCode.ok);
      final decoded = jsonDecode(out.output) as Map<String, dynamic>;
      final stack = decoded['stack'] as List;
      expectNearGiac(
        (stack.single as Map)['value'] as num,
        1.4142135623730950488,
      );
    });

    test("cx eval infix '2^0.5' matches Giac's 2^0.5 within 1e-12", () async {
      final code = await run(['eval', 'infix', '--json', '2^0.5']);
      expect(code, ExitCode.ok);
      final decoded = jsonDecode(out.output) as Map<String, dynamic>;
      final stack = decoded['stack'] as List;
      expectNearGiac(
        (stack.single as Map)['value'] as num,
        1.4142135623730950488,
      );
    });

    // Matrix product [[1,2],[3,4]] * [[5,6],[7,8]]. Giac:
    // evalf([[1,2],[3,4]]*[[5,6],[7,8]]) = [[19,22],[43,50]] (exact).
    test('cx eval rpn matrix product matches Giac within 1e-12', () async {
      final code = await run([
        'eval',
        'rpn',
        '--json',
        '~[[1,2],[3,4]] [[5,6],[7,8]] *',
      ]);
      expect(code, ExitCode.ok);
      final decoded = jsonDecode(out.output) as Map<String, dynamic>;
      final stack = decoded['stack'] as List;
      expectMatrixNearGiac((stack.single as Map)['value'], <List<double>>[
        <double>[19, 22],
        <double>[43, 50],
      ]);
    });

    test('cx eval infix matrix product matches Giac within 1e-12', () async {
      final code = await run([
        'eval',
        'infix',
        '--json',
        '~[[1,2],[3,4]]*[[5,6],[7,8]]',
      ]);
      expect(code, ExitCode.ok);
      final decoded = jsonDecode(out.output) as Map<String, dynamic>;
      final stack = decoded['stack'] as List;
      expectMatrixNearGiac((stack.single as Map)['value'], <List<double>>[
        <double>[19, 22],
        <double>[43, 50],
      ]);
    });

    // Negative-number RPN program via the shortcut. The coordinator's
    // literal "cx 1 -2 +" is three unquoted argv tokens, which G4 already
    // rejects as extraArgument, 64 (see "cx -1 2 + unquoted is
    // extraArgument" above); the grammar only accepts a negative-number
    // RPN program as a single quoted argument, e.g. cx '1 -2 +', the same
    // pattern the existing "cx '-1 2 +'" test above already exercises.
    // Giac: evalf(1-2) = -1 (exact), so this is an exact-value assertion,
    // not a tolerance one; still run through the JSON path via eval rpn
    // for a machine-checked value, plus the shortcut's own text output.
    test("cx '1 -2 +' (shortcut) matches Giac's 1-2 exactly", () async {
      final code = await run(['1 -2 +']);
      expect(code, ExitCode.ok);
      expect(out.output, contains('1: -1'));
    });

    test("cx eval rpn '~1 -2 +' matches Giac's 1-2 within 1e-12", () async {
      final code = await run(['eval', 'rpn', '--json', '~1 -2 +']);
      expect(code, ExitCode.ok);
      final decoded = jsonDecode(out.output) as Map<String, dynamic>;
      final stack = decoded['stack'] as List;
      expectNearGiac((stack.single as Map)['value'] as num, -1.0);
    });
  });
}
