// Tests for issue #26 (branded `cx` banner): the pure layout, its color
// rule, and the JSON contract. `BannerQuery` is the only production code
// that ever touches the real terminal or environment; every test here
// injects `hasTerminal`, `supportsAnsiEscapes` and `readEnvironmentVariable`
// instead, so none of them depends on the real console (issue #26 rule:
// "make both injectable so tests do not depend on the real console").
import 'package:calculatrix_cli/calculatrix_cli.dart';
import 'package:test/test.dart';

void main() {
  const s2Commands = {'eval rpn', 'eval infix'};
  const fullCommands = {
    'eval rpn',
    'eval infix',
    'doctor',
    'upgrade',
    'uninstall',
    'version',
  };

  BannerQuery buildQuery({
    String? version,
    String? updateNotice,
    Set<String> registeredCommands = const {},
    bool hasTerminal = false,
    bool supportsAnsiEscapes = false,
    Map<String, String> environment = const {},
  }) {
    return BannerQuery(
      BannerInput(),
      version: version,
      updateNotice: updateNotice,
      registeredCommands: registeredCommands,
      hasTerminal: () => hasTerminal,
      supportsAnsiEscapes: () => supportsAnsiEscapes,
      readEnvironmentVariable: (name) => environment[name],
    );
  }

  group('BannerQuery / renderBanner (issue #26)', () {
    test('plain banner with every command registered matches the design '
        'exactly (issue #26 acceptance: snapshot test)', () async {
      final output = await buildQuery(
        version: '0.8.0',
        registeredCommands: fullCommands,
      ).execute();

      expect(
        output.toText(),
        "  ┌─     ─┐\n"
        "  │ ●   ━ │   cx v0.8.0\n"
        "  │ ┃   ● │   Calculatrix: matrix-first RPN and infix calculator\n"
        "  └─     ─┘\n"
        "\n"
        "  Commands:\n"
        "    eval rpn     evaluate an RPN program     cx eval rpn '1 2 +'\n"
        "    eval infix   evaluate an expression      cx eval infix "
        '"2^0.5"\n'
        "    doctor       verify local installation\n"
        "    upgrade      update to latest version\n"
        "    uninstall    remove cx\n"
        "    version      print version\n"
        "\n"
        "  Quickstart:  cx '[[0,-1],[1,0]] 2 ^'",
      );
    });

    test(
      'with only the S2 routes registered, the optional commands are '
      'omitted (issue #26 scope 4: this PR does not depend on #25)',
      () async {
        final output = await buildQuery(
          version: '0.8.0',
          registeredCommands: s2Commands,
        ).execute();

        expect(
          output.toText(),
          "  ┌─     ─┐\n"
          "  │ ●   ━ │   cx v0.8.0\n"
          "  │ ┃   ● │   Calculatrix: matrix-first RPN and infix calculator\n"
          "  └─     ─┘\n"
          "\n"
          "  Commands:\n"
          "    eval rpn     evaluate an RPN program     cx eval rpn '1 2 +'\n"
          "    eval infix   evaluate an expression      cx eval infix "
          '"2^0.5"\n'
          "\n"
          "  Quickstart:  cx '[[0,-1],[1,0]] 2 ^'",
        );
      },
    );

    test(
      'with no version known, the logo line drops the version suffix',
      () async {
        final output = await buildQuery(
          registeredCommands: s2Commands,
        ).execute();
        expect(output.toText(), startsWith('  ┌─     ─┐\n  │ ●   ━ │   cx\n'));
        expect(output.toText(), isNot(contains(' v ')));
      },
    );

    test('the logo is about as tall as it is wide: 9 columns by 4 rows, '
        'since a terminal cell is roughly twice as tall as it is wide, and '
        'the brackets span the whole matrix (User, 2026-09-29)', () async {
      final output = await buildQuery(registeredCommands: s2Commands).execute();
      final rows = output.toText()!.split('\n').take(4).toList();
      for (final row in rows) {
        expect(row.substring(2, 11).runes.length, 9);
      }
      expect(rows[0], '  ┌─     ─┐');
      expect(rows[3], '  └─     ─┘');
      for (final row in rows.sublist(1, 3)) {
        expect(row[2], '│');
        expect(row[10], '│');
        expect(row.substring(11, 14), '   ');
      }
    });

    test('the logo uses only box-drawing and geometric glyphs, which every '
        'console font has: no U+23A0..U+23BF bracket pieces, which the '
        'legacy Windows console cannot draw (User, 2026-09-29)', () async {
      final output = await buildQuery(registeredCommands: s2Commands).execute();
      final logo = output.toText()!.split('\n').take(4).join();
      expect(logo.runes.where((r) => r >= 0x23A0 && r <= 0x23BF), isEmpty);
    });

    test('an update notice is appended when given', () async {
      final output = await buildQuery(
        version: '0.8.0',
        updateNotice: '0.8.0 -> 0.9.0',
        registeredCommands: s2Commands,
      ).execute();
      expect(output.toText(), endsWith('Update available: 0.8.0 -> 0.9.0'));
    });

    test('no update notice line when none is given', () async {
      final output = await buildQuery(
        version: '0.8.0',
        registeredCommands: s2Commands,
      ).execute();
      expect(output.toText(), isNot(contains('Update available')));
    });

    test('color is on only when the terminal, ANSI support and NO_COLOR all '
        'allow it, and the top-left dot uses the glow color (#2EF2C3) with a '
        'reset (issue #26 acceptance)', () async {
      final output = await buildQuery(
        version: '0.8.0',
        registeredCommands: s2Commands,
        hasTerminal: true,
        supportsAnsiEscapes: true,
        environment: {'COLORTERM': 'truecolor'},
      ).execute();
      final text = output.toText()!;
      expect(text, contains('\x1B[38;2;46;242;195m'));
      expect(text, contains('\x1B[0m'));
    });

    test('COLORTERM=24bit also selects the 24-bit glow', () async {
      final output = await buildQuery(
        registeredCommands: s2Commands,
        hasTerminal: true,
        supportsAnsiEscapes: true,
        environment: {'COLORTERM': '24bit'},
      ).execute();
      expect(output.toText(), contains('\x1B[38;2;46;242;195m'));
    });

    test('without COLORTERM truecolor the glow falls back to bright cyan '
        '(ANSI 96, issue #26 acceptance)', () async {
      final output = await buildQuery(
        registeredCommands: s2Commands,
        hasTerminal: true,
        supportsAnsiEscapes: true,
      ).execute();
      final text = output.toText()!;
      expect(text, contains('\x1B[96m●'));
      expect(text, isNot(contains('\x1B[38;2;')));
    });

    test('color output strips to exactly the plain banner text', () async {
      final colored = await buildQuery(
        version: '0.8.0',
        registeredCommands: fullCommands,
        hasTerminal: true,
        supportsAnsiEscapes: true,
      ).execute();
      final plain = await buildQuery(
        version: '0.8.0',
        registeredCommands: fullCommands,
      ).execute();
      final stripped = colored.toText()!.replaceAll(
        RegExp('\x1B\\[[0-9;]*m'),
        '',
      );
      expect(stripped, plain.toText());
    });

    test(
      'no color when stdout is not a terminal, even without NO_COLOR',
      () async {
        final output = await buildQuery(
          version: '0.8.0',
          registeredCommands: s2Commands,
          hasTerminal: false,
          supportsAnsiEscapes: true,
        ).execute();
        expect(output.toText(), isNot(contains('\x1B[')));
      },
    );

    test('no color when the terminal does not support ANSI escapes', () async {
      final output = await buildQuery(
        version: '0.8.0',
        registeredCommands: s2Commands,
        hasTerminal: true,
        supportsAnsiEscapes: false,
      ).execute();
      expect(output.toText(), isNot(contains('\x1B[')));
    });

    test('NO_COLOR disables color on an otherwise ANSI-capable terminal '
        '(https://no-color.org)', () async {
      final output = await buildQuery(
        version: '0.8.0',
        registeredCommands: s2Commands,
        hasTerminal: true,
        supportsAnsiEscapes: true,
        environment: const {'NO_COLOR': '1'},
      ).execute();
      expect(output.toText(), isNot(contains('\x1B[')));
    });

    test('NO_COLOR disables color regardless of its value, even empty '
        '(https://no-color.org)', () async {
      final output = await buildQuery(
        version: '0.8.0',
        registeredCommands: s2Commands,
        hasTerminal: true,
        supportsAnsiEscapes: true,
        environment: const {'NO_COLOR': ''},
      ).execute();
      expect(output.toText(), isNot(contains('\x1B[')));
    });

    test('JSON mode keeps name and tagline and adds version when known '
        '(issue #26 scope 6)', () async {
      final output = await buildQuery(
        version: '0.8.0',
        registeredCommands: s2Commands,
      ).execute();
      expect(output.toJson(), {
        'name': 'cx',
        'tagline': 'Calculatrix: matrix-first RPN and infix calculator',
        'version': '0.8.0',
      });
    });

    test('JSON mode omits version when it is not known', () async {
      final output = await buildQuery(registeredCommands: s2Commands).execute();
      expect(output.toJson(), {
        'name': 'cx',
        'tagline': 'Calculatrix: matrix-first RPN and infix calculator',
      });
    });
  });
}
