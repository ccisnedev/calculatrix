// Differential tests of the exact words of step T2 against Giac (runbook
// D57): `+ - * /`, `negate`, `percent` and integer powers, on generated
// exact inputs with fixed seeds, from trivial sizes to results near the
// limit of 10000 digits. Each case runs through the RPN evaluator and
// through Giac, and the two results must agree entry by entry as exact
// rationals.
//
// Giac is the judge only, never a dependency: in CI a Linux job installs
// it from the distribution packages; on Windows it runs through WSL
// (`wsl -d Ubuntu -- giac`). Where it is missing, the test is skipped with
// a message.
@Tags(['giac'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

/// One generated case: the same computation as an RPN program and as a
/// Giac expression.
final class _Case {
  _Case(this.name, this.rpn, this.giac);

  final String name;
  final String rpn;
  final String giac;
}

/// An exact operand: a matrix of integers over one common denominator, so
/// both sides can spell it without fraction literals.
final class _Operand {
  _Operand(this.rows, this.denominator);

  final List<List<BigInt>> rows;
  final BigInt denominator;

  int get size => rows.length;

  bool get isScalar => rows.length == 1 && rows.first.length == 1;

  String _matrix(String separator, String rowSeparator) =>
      '[${rows.map((List<BigInt> row) => '[${row.join(separator)}]').join(rowSeparator)}]';

  String get rpn => isScalar
      ? '${rows.first.first} $denominator /'
      : '${_matrix(' ', ' ')} $denominator /';

  String get giac => isScalar
      ? '(${rows.first.first}/$denominator)'
      : '(${_matrix(',', ',')}/$denominator)';
}

final class _Generator {
  _Generator(int seed) : _random = math.Random(seed);

  final math.Random _random;

  BigInt integer(int digits) {
    final StringBuffer buffer = StringBuffer(_random.nextInt(9) + 1);
    for (int i = 1; i < digits; i++) {
      buffer.write(_random.nextInt(10));
    }
    final BigInt value = BigInt.parse(buffer.toString());
    return _random.nextInt(4) == 0 ? -value : value;
  }

  // Mostly small entries, with zeros and a few large ones mixed in.
  BigInt entry(int maxDigits) => switch (_random.nextInt(6)) {
    0 => BigInt.zero,
    1 => integer(_random.nextInt(maxDigits) + 1),
    _ => integer(_random.nextInt(2) + 1),
  };

  BigInt denominator(int maxDigits) {
    final BigInt value = integer(_random.nextInt(maxDigits) + 1).abs();
    return value == BigInt.zero ? BigInt.one : value;
  }

  _Operand operand(int rows, int columns, int maxDigits) => _Operand(
    List<List<BigInt>>.generate(
      rows,
      (_) => List<BigInt>.generate(columns, (_) => entry(maxDigits)),
    ),
    denominator(maxDigits),
  );

  int nextInt(int max) => _random.nextInt(max);
}

List<_Case> _cases() {
  final List<_Case> cases = <_Case>[];
  final _Generator g = _Generator(54);

  for (final int digits in <int>[1, 3, 12, 40, 200]) {
    for (int i = 0; i < 8; i++) {
      final _Operand a = g.operand(1, 1, digits);
      final _Operand b = g.operand(1, 1, digits);
      final String tag = 'scalar d$digits #$i';
      cases
        ..add(_Case('$tag +', '${a.rpn} ${b.rpn} +', '${a.giac}+${b.giac}'))
        ..add(_Case('$tag -', '${a.rpn} ${b.rpn} -', '${a.giac}-${b.giac}'))
        ..add(_Case('$tag *', '${a.rpn} ${b.rpn} *', '${a.giac}*${b.giac}'))
        ..add(_Case('$tag negate', '${a.rpn} negate', '-${a.giac}'))
        ..add(_Case('$tag percent', '${a.rpn} %', '${a.giac}/100'));
      if (b.rows.first.first != BigInt.zero) {
        cases.add(
          _Case('$tag /', '${a.rpn} ${b.rpn} /', '${a.giac}/${b.giac}'),
        );
      }
    }
  }

  // Integer powers of scalars, up to results of a few thousand digits.
  for (final (int digits, int maxExponent) in <(int, int)>[
    (1, 30),
    (3, 200),
    (20, 150),
  ]) {
    for (int i = 0; i < 10; i++) {
      final _Operand a = g.operand(1, 1, digits);
      if (a.rows.first.first == BigInt.zero) {
        continue;
      }
      final int exponent = g.nextInt(2 * maxExponent + 1) - maxExponent;
      cases.add(
        _Case(
          'scalar power d$digits #$i ^$exponent',
          '${a.rpn} $exponent ^',
          '${a.giac}^($exponent)',
        ),
      );
    }
  }

  // Near the default limit of 10000 digits.
  for (int i = 0; i < 4; i++) {
    final BigInt a = g.integer(4400 + g.nextInt(500));
    final BigInt b = g.integer(4400 + g.nextInt(500));
    final BigInt c = g.integer(9000 + g.nextInt(900));
    final String tag = 'near the limit #$i';
    cases
      ..add(_Case('$tag *', '$a $b *', '$a*$b'))
      ..add(_Case('$tag /', '$c $b /', '$c/$b'))
      ..add(_Case('$tag +', '$c $a / $b +', '$c/$a+$b'));
  }
  for (final (int base, int exponent) in <(int, int)>[
    (7, 11000),
    (-3, 20001),
    (12345, -2200),
  ]) {
    cases.add(
      _Case(
        'near the limit $base^$exponent',
        '$base $exponent ^',
        '($base)^($exponent)',
      ),
    );
  }

  // Matrices: elementwise, products, scalar operations and promotion.
  for (final int size in <int>[1, 2, 3, 4]) {
    for (final int digits in <int>[1, 6, 25]) {
      for (int i = 0; i < 3; i++) {
        final _Operand a = g.operand(size, size, digits);
        final _Operand b = g.operand(size, size, digits);
        final _Operand c = g.operand(1, 1, digits);
        final String tag = 'matrix ${size}x$size d$digits #$i';
        cases
          ..add(_Case('$tag +', '${a.rpn} ${b.rpn} +', '${a.giac}+${b.giac}'))
          ..add(_Case('$tag -', '${a.rpn} ${b.rpn} -', '${a.giac}-${b.giac}'))
          ..add(_Case('$tag *', '${a.rpn} ${b.rpn} *', '${a.giac}*${b.giac}'))
          ..add(_Case('$tag negate', '${a.rpn} negate', '-${a.giac}'))
          ..add(_Case('$tag percent', '${a.rpn} %', '${a.giac}/100'))
          ..add(
            _Case(
              '$tag scalar *',
              '${c.rpn} ${a.rpn} *',
              '${c.giac}*${a.giac}',
            ),
          );
        if (c.rows.first.first != BigInt.zero) {
          cases.add(
            _Case(
              '$tag scalar /',
              '${a.rpn} ${c.rpn} /',
              '${a.giac}/${c.giac}',
            ),
          );
        }
        if (size > 1) {
          // A scalar meets a square matrix as itself times the identity.
          cases.add(
            _Case(
              '$tag scalar +',
              '${a.rpn} ${c.rpn} +',
              '${a.giac}+${c.giac}*idn($size)',
            ),
          );
        }
        final int exponent = g.nextInt(digits == 25 ? 8 : 20);
        cases.add(
          _Case(
            '$tag ^$exponent',
            '${a.rpn} $exponent ^',
            '${a.giac}^$exponent',
          ),
        );
      }
    }
  }

  // Rectangular products.
  for (int i = 0; i < 12; i++) {
    final int rows = g.nextInt(4) + 1;
    final int inner = g.nextInt(4) + 1;
    final int columns = g.nextInt(4) + 1;
    final _Operand a = g.operand(rows, inner, 8);
    final _Operand b = g.operand(inner, columns, 8);
    if (a.isScalar || b.isScalar) {
      continue;
    }
    cases.add(
      _Case(
        'product ${rows}x$inner by ${inner}x$columns #$i',
        '${a.rpn} ${b.rpn} *',
        '${a.giac}*${b.giac}',
      ),
    );
  }
  return cases;
}

List<String> _giacCommand() => Platform.isWindows
    ? <String>['wsl', '-d', 'Ubuntu', '--', 'giac']
    : <String>['giac'];

/// Runs every expression through one Giac process and returns its results
/// by index, or null when Giac cannot run here.
Future<Map<int, String>?> _runGiac(List<String> expressions) async {
  final List<String> command = _giacCommand();
  final Process process;
  try {
    process = await Process.start(command.first, command.sublist(1));
  } on ProcessException {
    return null;
  }
  final StringBuffer input = StringBuffer();
  for (int i = 0; i < expressions.length; i++) {
    input.writeln('print("R$i "+string(${expressions[i]}));');
  }
  process.stdin.write(input.toString());
  await process.stdin.close();
  // Giac's print writes to stderr; read both streams.
  final Future<String> output = process.stdout
      .transform(const Utf8Decoder(allowMalformed: true))
      .join();
  final Future<String> errors = process.stderr
      .transform(const Utf8Decoder(allowMalformed: true))
      .join();
  final String text = '${await errors}\n${await output}'.replaceAll(
    '\u0000',
    '',
  );
  await process.exitCode;

  final Map<int, String> results = <int, String>{};
  final RegExp line = RegExp(r'^R(\d+) (.*)$');
  // Giac wraps long results over several lines; join them back.
  int? current;
  for (final String raw in const LineSplitter().convert(text)) {
    final RegExpMatch? match = line.firstMatch(raw);
    if (match != null) {
      current = int.parse(match.group(1)!);
      results[current] = match.group(2)!.trim();
    } else if (current != null &&
        RegExp(r'^[-0-9/\[\],]+$').hasMatch(raw.trim()) &&
        raw.trim().isNotEmpty) {
      results[current] = results[current]! + raw.trim();
    } else {
      current = null;
    }
  }
  return results.isEmpty ? null : results;
}

/// Giac's text of a number or matrix, as a flat list of canonical
/// rationals. Some matrix results come as `matrix[[...]]`.
List<String> _giacEntries(String text) => text
    .replaceAll(RegExp(r'matrix|[\[\]\s]'), '')
    .split(',')
    .map(_canonical)
    .toList();

String _canonical(String rational) {
  final List<String> parts = rational.split('/');
  final Rational value = parts.length == 1
      ? Rational(BigInt.parse(parts[0]), BigInt.one)
      : Rational(BigInt.parse(parts[0]), BigInt.parse(parts[1]));
  return _text(value);
}

String _text(Rational value) => value.denominator == BigInt.one
    ? '${value.numerator}'
    : '${value.numerator}/${value.denominator}';

void main() {
  final List<_Case> cases = _cases();
  late final Map<int, String>? giac;

  setUpAll(() async {
    giac = await _runGiac(cases.map((_Case c) => c.giac).toList());
  });

  test('Giac agrees with every exact result of step T2', () {
    if (giac == null) {
      // The CI job sets this, so a broken Giac install fails there instead
      // of passing silently.
      if (Platform.environment['CALCULATRIX_REQUIRE_GIAC'] == '1') {
        fail('Giac is required but did not run (${_giacCommand().join(' ')}).');
      }
      markTestSkipped(
        'Giac is not available (${_giacCommand().join(' ')}); skipping the '
        'differential tests.',
      );
      return;
    }
    expect(cases.length, greaterThan(250));
    int largest = 0;
    for (int i = 0; i < cases.length; i++) {
      final _Case c = cases[i];
      final Matrix result = Calculatrix.evaluateRpn(
        Calculatrix.tokenizeRpnLine(c.rpn),
      );
      expect(result.isExact, isTrue, reason: c.name);
      final List<String> ours = <String>[
        for (final List<Rational> row in result.exactRows)
          for (final Rational entry in row) _text(entry),
      ];
      for (final List<Rational> row in result.exactRows) {
        for (final Rational entry in row) {
          largest = math.max(largest, entry.digits);
        }
      }
      final String? theirs = giac![i];
      expect(theirs, isNotNull, reason: '${c.name}: no Giac result');
      expect(ours, _giacEntries(theirs!), reason: '${c.name}: ${c.rpn}');
    }
    // The cases reach results near the default limit of 10000 digits.
    expect(largest, greaterThan(9000));
  });
}
