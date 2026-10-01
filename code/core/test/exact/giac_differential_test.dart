// Differential tests of the exact words against Giac (runbook D57): step
// T2's `+ - * /`, `negate`, `percent` and integer powers, and step T3's
// `inverse`, `determinant`, `rref`, `rank`, `trace`, `adjugate`,
// `cofactors`, `lu`, `dot`, `cross` and negative matrix powers, and step
// T4's fractional powers (`sqrt` among them), `eigenvalues`,
// `frobenius-norm`, `exp` and `ln`, on generated exact inputs with fixed
// seeds, from trivial sizes to results near the limit of 10000 digits.
// Each case runs through the RPN evaluator and through Giac, and the two
// results must agree entry by entry as exact rationals. For the T4 words
// Giac also says when the true result is not rational ("irr"); then cx
// must give an approximate result or an error, never an exact one.
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

  /// Always a Giac matrix, even for a 1x1, which the matrix words need.
  String get giacMatrix => '(${_matrix(',', ',')}/$denominator)';

  /// A column vector as a Giac list, which `dot` and `cross` take.
  String get giacVector =>
      '([${rows.map((List<BigInt> row) => row.first).join(',')}]/$denominator)';

  /// Whether the square matrix is singular, by plain rational elimination
  /// (independent of the fraction-free code under test).
  bool get isSingular {
    final List<List<Rational>> work = rows
        .map((List<BigInt> row) => row.map((BigInt v) => Rational(v)).toList())
        .toList();
    final int n = work.length;
    for (int c = 0; c < n; c++) {
      final int pivot = work.indexWhere(
        (List<Rational> row) => !row[c].isZero,
        c,
      );
      if (pivot < 0) {
        return true;
      }
      final List<Rational> held = work[c];
      work[c] = work[pivot];
      work[pivot] = held;
      for (int r = c + 1; r < n; r++) {
        final Rational factor = work[r][c] / work[c][c];
        for (int j = c; j < n; j++) {
          work[r][j] = work[r][j] - factor * work[c][j];
        }
      }
    }
    return false;
  }

  /// The same matrix with its last [dependent] rows replaced by sums of
  /// the rows it keeps, so its rank is at most n - [dependent].
  _Operand withDependentRows(int dependent) {
    final int kept = rows.length - dependent;
    return _Operand(<List<BigInt>>[
      ...rows.sublist(0, kept),
      for (int j = 0; j < dependent; j++)
        List<BigInt>.generate(
          rows.first.length,
          (int c) => rows
              .take(math.min(j + 1, kept))
              .fold(
                BigInt.zero,
                (BigInt sum, List<BigInt> row) => sum + row[c],
              ),
        ),
    ], denominator);
  }
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

  _linearAlgebraCases(g, cases);
  _rootCases(g, cases);
  return cases;
}

// Giac has no cofactor word; this builds the matrix from minors.
String _giacCofactors(String a, int n) =>
    '(B->makemat((j,k)->(-1)^(j+k)*det(delcols(delrows(B,j),k)),$n,$n))($a)';

// Giac's lu pivots on the entry of smallest magnitude and cx's on the
// largest, so their P differ. Given cx's P, the L U of M = P A without
// pivoting is unique; these build it in Giac from minors of M:
// U[i][j] = det(M[0..i][0..i-1, j]) / det(M[0..i-1][0..i-1]) and
// L[i][j] = det(M[0..j-1, i][0..j]) / det(M[0..j][0..j]).
String _giacUpper(String m, int n) =>
    '(M->makemat((i,j)->when(j<i,0,'
    'det(makemat((r,c)->M[r][when(c<i,c,j)],i+1,i+1))'
    '/when(i==0,1,det(makemat((r,c)->M[r][c],i,i)))),$n,$n))($m)';

String _giacLower(String m, int n) =>
    '(M->makemat((i,j)->when(i<j,0,when(i==j,1,'
    'det(makemat((r,c)->M[when(r<j,r,i)][c],j+1,j+1))'
    '/det(makemat((r,c)->M[r][c],j+1,j+1)))),$n,$n))($m)';

/// [a] with its rows in the order of cx's P from `lu`.
_Operand _permutedByLu(_Operand a) {
  final Matrix p = Calculatrix.evaluateRpnStack(
    Calculatrix.tokenizeRpnLine('${a.rpn} lu'),
  ).first;
  return _Operand(<List<BigInt>>[
    for (int r = 0; r < a.size; r++)
      a.rows[List<int>.generate(
        a.size,
        (int c) => c,
      ).firstWhere((int c) => p.exactAt(r, c) == Rational.one)],
  ], a.denominator);
}

void _squareCases(String tag, _Operand a, List<_Case> cases, _Generator g) {
  final int n = a.size;
  cases
    ..add(
      _Case('$tag determinant', '${a.rpn} determinant', 'det(${a.giacMatrix})'),
    )
    ..add(_Case('$tag trace', '${a.rpn} trace', 'trace(${a.giacMatrix})'))
    ..add(_Case('$tag rank', '${a.rpn} rank', 'rank(${a.giacMatrix})'))
    ..add(_Case('$tag rref', '${a.rpn} rref', 'rref(${a.giacMatrix})'));
  if (n > 1) {
    cases
      ..add(
        _Case(
          '$tag cofactors',
          '${a.rpn} cofactors',
          _giacCofactors(a.giacMatrix, n),
        ),
      )
      ..add(
        _Case(
          '$tag adjugate',
          '${a.rpn} adjugate',
          'tran(${_giacCofactors(a.giacMatrix, n)})',
        ),
      );
  }
  if (a.isSingular) {
    return;
  }
  cases.add(_Case('$tag inverse', '${a.rpn} inverse', 'inv(${a.giacMatrix})'));
  if (n > 1) {
    final int exponent = -(g.nextInt(3) + 1);
    // Compared on nonsingular matrices, where L and U are unique;
    // exact_linear_algebra_test checks P A = L U on singular ones.
    final _Operand m = _permutedByLu(a);
    cases
      ..add(
        _Case(
          '$tag ^$exponent',
          '${a.rpn} $exponent ^',
          '${a.giacMatrix}^($exponent)',
        ),
      )
      ..add(
        _Case(
          '$tag lu L',
          '${a.rpn} lu drop swap drop',
          _giacLower(m.giacMatrix, n),
        ),
      )
      ..add(
        _Case(
          '$tag lu U',
          '${a.rpn} lu swap drop swap drop',
          _giacUpper(m.giacMatrix, n),
        ),
      );
  }
}

void _linearAlgebraCases(_Generator g, List<_Case> cases) {
  // Square matrices: random (almost always nonsingular) and made singular.
  for (final int size in <int>[1, 2, 3, 4, 5]) {
    for (final int digits in <int>[1, 4, 15]) {
      for (int i = 0; i < 3; i++) {
        final _Operand a = g.operand(size, size, digits);
        final String tag = 'T3 ${size}x$size d$digits';
        _squareCases('$tag #$i', a, cases, g);
        if (size > 1 && i == 0) {
          _squareCases('$tag rank n-1', a.withDependentRows(1), cases, g);
        }
        if (size > 2 && i == 1) {
          _squareCases('$tag rank n-2', a.withDependentRows(2), cases, g);
        }
      }
    }
  }

  // Rectangular rref and rank.
  for (int i = 0; i < 12; i++) {
    final int rows = g.nextInt(4) + 1;
    final int columns = g.nextInt(5) + 1;
    final _Operand a = g.operand(rows, columns, 5);
    if (a.isScalar) {
      continue;
    }
    final String tag = 'T3 ${rows}x$columns #$i';
    cases
      ..add(_Case('$tag rref', '${a.rpn} rref', 'rref(${a.giac})'))
      ..add(_Case('$tag rank', '${a.rpn} rank', 'rank(${a.giac})'));
  }

  // Dot and cross products.
  for (final int digits in <int>[1, 8, 60]) {
    for (int i = 0; i < 4; i++) {
      final int length = g.nextInt(5) + 1;
      final _Operand u = g.operand(length, 1, digits);
      final _Operand v = g.operand(length, 1, digits);
      final _Operand x = g.operand(3, 1, digits);
      final _Operand y = g.operand(3, 1, digits);
      cases
        ..add(
          _Case(
            'T3 dot $length d$digits #$i',
            '${u.rpn} ${v.rpn} dot',
            'dot(${u.giacVector},${v.giacVector})',
          ),
        )
        ..add(
          _Case(
            'T3 cross d$digits #$i',
            '${x.rpn} ${y.rpn} cross',
            'cross(${x.giacVector},${y.giacVector})',
          ),
        );
    }
  }

  // Near the default limit of 10000 digits: a determinant of about 8800
  // digits and an inverse whose denominators have about 4200.
  for (final (String word, String giacWord, int size, int digits)
      in <(String, String, int, int)>[
        ('determinant', 'det', 4, 2190),
        ('inverse', 'inv', 3, 1400),
      ]) {
    final _Operand a = _Operand(
      List<List<BigInt>>.generate(
        size,
        (_) => List<BigInt>.generate(size, (_) => g.integer(digits)),
      ),
      BigInt.one,
    );
    cases.add(
      _Case(
        'T3 near the limit $word',
        '${a.rpn} $word',
        '$giacWord(${a.giac})',
      ),
    );
  }
}

// Giac functions the T4 cases call. `chk` simplifies a result and gives
// it back when every entry is rational, or "irr"; `cx2` writes a complex
// number in cx's 2x2 form; `egr` gives the eigenvalues of a matrix,
// largest first and repeated by multiplicity, when all are rational.
const List<String> _giacPrelude = <String>[
  'chk(v):={local s,L,k; s:=simplify(v); if type(s)==DOM_LIST then '
      'L:=flatten(s); else L:=[s]; fi; for k from 0 to size(L)-1 do '
      'if type(L[k])!=DOM_INT and type(L[k])!=DOM_RAT then return "irr"; '
      'fi; od; return s;}',
  'cx2(z):=[[re(z),-im(z)],[im(z),re(z)]]',
  'egr(M):={local P,res,r; P:=normal(charpoly(M,x)); res:=[]; '
      'for r in rationalroot(P) do while normal(subst(P,x=r))==0 do '
      'res:=append(res,r); P:=normal(quo(P,x-r,x)); od; od; '
      'if degree(P,x)>0 then return "irr"; fi; return revlist(sort(res));}',
];

/// What `chk` and `egr` print for a result that is not rational.
const String _irrational = '"irr"';

/// The Giac q-th root of n/d >= 0, from the roots of n and d, which Giac
/// simplifies (it leaves (27/64)^(2/3) alone).
String _giacRoot(BigInt n, BigInt d, int q) =>
    '(simplify(($n)^(1/$q))/simplify(($d)^(1/$q)))';

List<List<BigInt>> _multiply(List<List<BigInt>> a, List<List<BigInt>> b) =>
    List<List<BigInt>>.generate(a.length, (int r) {
      return List<BigInt>.generate(b.first.length, (int c) {
        BigInt sum = BigInt.zero;
        for (int k = 0; k < b.length; k++) {
          sum += a[r][k] * b[k][c];
        }
        return sum;
      });
    });

List<List<BigInt>> _diagonal(List<BigInt> entries) =>
    List<List<BigInt>>.generate(
      entries.length,
      (int r) => List<BigInt>.generate(
        entries.length,
        (int c) => r == c ? entries[r] : BigInt.zero,
      ),
    );

List<List<BigInt>> _integerIdentity(int n) =>
    _diagonal(List<BigInt>.filled(n, BigInt.one));

/// A random unimodular integer matrix S and its inverse, from row
/// additions: E S has inverse S^-1 E^-1.
(List<List<BigInt>>, List<List<BigInt>>) _unimodular(_Generator g, int n) {
  final List<List<BigInt>> s = _integerIdentity(n);
  final List<List<BigInt>> inverse = _integerIdentity(n);
  for (int step = 0; step < 2 * n; step++) {
    final int i = g.nextInt(n);
    final int j = g.nextInt(n);
    if (i == j) {
      continue;
    }
    final BigInt c = BigInt.from(g.nextInt(5) - 2);
    for (int k = 0; k < n; k++) {
      s[i][k] += c * s[j][k];
      inverse[k][j] -= c * inverse[k][i];
    }
  }
  return (s, inverse);
}

void _rootCases(_Generator g, List<_Case> cases) {
  // Scalar powers p/q of n/d: exact ones built from q-th powers, and
  // random ones, mostly irrational. A negative base has the principal
  // complex root |b|^(p/q) e^(i pi p/q), rational only for q = 2 and 4.
  for (final int q in <int>[2, 3, 4, 5]) {
    for (int i = 0; i < 12; i++) {
      final int digits = <int>[1, 3, 12][i % 3];
      BigInt n = g.integer(digits);
      BigInt d = g.denominator(digits);
      if (i.isEven) {
        n = n.isNegative ? -n.abs().pow(q) : n.pow(q);
        d = d.pow(q);
      }
      int p = g.nextInt(9) - 4;
      while (p == 0 || p.gcd(q) != 1) {
        p = g.nextInt(9) - 4;
      }
      final String root = _giacRoot(n.abs(), d, q);
      final String giac = n.isNegative
          ? 'chk(cx2($root^($p)*exp(i*pi*($p)/$q)))'
          : 'chk($root^($p))';
      cases.add(
        _Case('T4 scalar ^$p/$q d$digits #$i', '$n $d / $p $q / power', giac),
      );
      if (p == 1 && q == 2) {
        cases.add(_Case('T4 scalar sqrt d$digits #$i', '$n $d / sqrt', giac));
      }
    }
  }
  // Negative bases -4 x^4 / d^4, whose fourth roots (1 + i) x / d are
  // rational, and -x^2 / d^2, whose fourth roots are not.
  for (int i = 0; i < 12; i++) {
    final int digits = <int>[1, 3, 12][i % 3];
    final BigInt x = g.integer(digits).abs() + BigInt.one;
    final BigInt d = g.denominator(digits);
    final BigInt n = i.isEven
        ? -BigInt.from(4) * x.pow(4)
        : -(x.pow(2) * BigInt.two);
    final BigInt denominator = i.isEven ? d.pow(4) : d.pow(2);
    final int p = <int>[1, 3, -1, -3, 5][g.nextInt(5)];
    final String root = _giacRoot(-n, denominator, 4);
    cases.add(
      _Case(
        'T4 negative ^$p/4 d$digits #$i',
        '$n $denominator / $p 4 / power',
        'chk(cx2(simplify($root^($p)*exp(i*pi*($p)/4))))',
      ),
    );
  }
  cases
    ..add(_Case('T4 0 sqrt', '0 sqrt', 'chk(0)'))
    ..add(_Case('T4 0 ^3/2', '0 3 2 / power', 'chk(0)'))
    ..add(_Case('T4 0 ^-1/2', '0 -1 2 / power', _irrational));

  // Complex numbers [[a -b] [b a]]: square roots and their odd powers.
  // The exact ones are (x + yi)^2 / d^2.
  for (int i = 0; i < 24; i++) {
    final int digits = <int>[1, 4, 10][i % 3];
    BigInt a = g.integer(digits);
    BigInt b = g.integer(digits);
    BigInt d = g.denominator(digits);
    if (i.isEven) {
      final BigInt x = a;
      final BigInt y = b;
      a = x * x - y * y;
      b = BigInt.two * x * y;
      d = d * d;
    }
    if (a == BigInt.zero && b == BigInt.zero) {
      continue;
    }
    final int p = <int>[1, 1, 3, -1, -3, 5][g.nextInt(6)];
    final _Operand z = _Operand(<List<BigInt>>[
      <BigInt>[a, -b],
      <BigInt>[b, a],
    ], d);
    cases.add(
      _Case(
        'T4 complex ^$p/2 d$digits #$i',
        '${z.rpn} $p 2 / power',
        'chk(cx2(sqrt(($a+($b)*i)/$d)^($p)))',
      ),
    );
  }

  // Diagonal matrices with nonzero entries: q-th powers, plain integers
  // and negative ones, which have no real root (Giac's is complex).
  for (int i = 0; i < 16; i++) {
    final int n = g.nextInt(3) + 2;
    final int q = <int>[2, 2, 3][g.nextInt(3)];
    final int p = q == 2
        ? <int>[1, 1, 3, -1][g.nextInt(4)]
        : <int>[1, 2, -1][g.nextInt(3)];
    final List<BigInt> entries = <BigInt>[
      for (int k = 0; k < n; k++)
        i % 4 == 3
            ? g.integer(2)
            : BigInt.from(g.nextInt(30) + 1).pow(i % 4 == 2 ? 1 : q),
    ];
    if (entries.contains(BigInt.zero)) {
      continue;
    }
    final BigInt d = BigInt.from(g.nextInt(9) + 1).pow(q);
    final _Operand m = _Operand(_diagonal(entries), d);
    // Entry by entry: Giac's matpow leaves some rational roots unsimplified.
    // A negative entry has the complex principal root, never real here.
    final String roots = entries
        .map(
          (BigInt e) => e.isNegative
              ? '${_giacRoot(-e, d, q)}^($p)*exp(i*pi*($p)/$q)'
              : '${_giacRoot(e, d, q)}^($p)',
        )
        .join(',');
    cases.add(
      _Case(
        'T4 diagonal ${n}x$n ^$p/$q #$i',
        '${m.rpn} $p $q / power',
        'chk(diag([$roots]))',
      ),
    );
  }

  // General matrices: M = X^2 for a symmetric positive definite X, whose
  // principal square root is X, so M^(p/2) is X^p. cx finds an exact root
  // from an approximate guess, so X = A^T A + 3I is kept well conditioned.
  // Roots of higher index are covered on scalars and diagonal matrices:
  // the approximate matrix logarithm that guesses them is not accurate
  // enough on general matrices.
  for (int i = 0; i < 16; i++) {
    final int n = g.nextInt(3) + 2;
    const int q = 2;
    final int p = <int>[1, 1, -1, 3][g.nextInt(4)];
    final List<List<BigInt>> a = List<List<BigInt>>.generate(
      n,
      (_) => List<BigInt>.generate(n, (_) => BigInt.from(g.nextInt(5) - 2)),
    );
    final List<List<BigInt>> transposed = List<List<BigInt>>.generate(
      n,
      (int r) => List<BigInt>.generate(n, (int c) => a[c][r]),
    );
    final List<List<BigInt>> x = _multiply(transposed, a);
    for (int k = 0; k < n; k++) {
      x[k][k] += BigInt.from(3);
    }
    List<List<BigInt>> m = x;
    for (int k = 1; k < q; k++) {
      m = _multiply(m, x);
    }
    final BigInt d = BigInt.from(g.nextInt(4) + 1);
    final _Operand base = _Operand(m, d.pow(q));
    final _Operand root = _Operand(x, d);
    cases.add(
      _Case(
        'T4 general ${n}x$n ^$p/$q #$i',
        '${base.rpn} $p $q / power',
        'chk(${root.giacMatrix}^($p))',
      ),
    );
    if (p == 1 && q == 2) {
      cases.add(
        _Case(
          'T4 general ${n}x$n sqrt #$i',
          '${base.rpn} sqrt',
          'chk(${root.giacMatrix})',
        ),
      );
    }
  }
  // Random 2x2 matrices: usually irrational, or with no real root.
  for (int i = 0; i < 10; i++) {
    final _Operand m = g.operand(2, 2, 2);
    cases.add(
      _Case(
        'T4 random 2x2 sqrt #$i',
        '${m.rpn} sqrt',
        'chk(matpow(${m.giacMatrix},1/2))',
      ),
    );
  }

  // Eigenvalues: S D S^-1 for a unimodular S and a rational diagonal D
  // with repeated entries, triangular matrices, and random ones (mostly
  // irrational or complex).
  for (final int n in <int>[2, 3, 4, 5, 6]) {
    for (int i = 0; i < 6; i++) {
      final int digits = <int>[1, 3, 8][i % 3];
      final _Operand m;
      if (i < 3) {
        final List<BigInt> values = <BigInt>[
          for (int k = 0; k < n; k++)
            g.nextInt(4) == 0 ? BigInt.zero : g.integer(digits),
        ];
        for (int k = 1; k < n; k++) {
          if (g.nextInt(3) == 0) {
            values[k] = values[k - 1];
          }
        }
        final (List<List<BigInt>> s, List<List<BigInt>> inverse) = _unimodular(
          g,
          n,
        );
        m = _Operand(
          _multiply(_multiply(s, _diagonal(values)), inverse),
          g.denominator(digits),
        );
      } else if (i < 5) {
        final _Operand random = g.operand(n, n, digits);
        m = _Operand(<List<BigInt>>[
          for (int r = 0; r < n; r++)
            <BigInt>[
              for (int c = 0; c < n; c++)
                c < r ? BigInt.zero : random.rows[r][c],
            ],
        ], random.denominator);
      } else {
        m = g.operand(n, n, digits);
      }
      cases.add(
        _Case(
          'T4 eigenvalues ${n}x$n d$digits #$i',
          '${m.rpn} eigenvalues',
          'egr(${m.giacMatrix})',
        ),
      );
    }
  }
  cases
    ..add(
      _Case(
        'T4 eigenvalues rotation',
        '[[0 -1] [1 0]] eigenvalues',
        'egr([[0,-1],[1,0]])',
      ),
    )
    ..add(
      _Case(
        'T4 eigenvalues nilpotent',
        '[[0 1 2] [0 0 3] [0 0 0]] eigenvalues',
        'egr([[0,1,2],[0,0,3],[0,0,0]])',
      ),
    );

  // Frobenius norms: scaled Pythagorean tuples, and random matrices.
  const List<List<int>> tuples = <List<int>>[
    <int>[3, 4],
    <int>[5, 12],
    <int>[1, 2, 2],
    <int>[2, 3, 6],
    <int>[1, 4, 8],
    <int>[2, 6, 9],
    <int>[1, 2, 4, 10],
    <int>[0, 0, 0, 7],
  ];
  for (int i = 0; i < tuples.length; i++) {
    final BigInt k = g.integer(1 + i * 3).abs();
    final List<BigInt> entries = <BigInt>[
      for (final int v in tuples[i])
        BigInt.from(g.nextInt(2) == 0 ? v : -v) * k,
    ];
    final int columns = entries.length == 4 ? 2 : entries.length;
    final _Operand pythagorean = _Operand(<List<BigInt>>[
      for (int r = 0; r < entries.length ~/ columns; r++)
        entries.sublist(r * columns, (r + 1) * columns),
    ], g.denominator(3));
    final _Operand random = g.operand(g.nextInt(3) + 1, g.nextInt(3) + 1, 4);
    for (final (String tag, _Operand m) in <(String, _Operand)>[
      ('pythagorean', pythagorean),
      ('random', random),
    ]) {
      cases.add(
        _Case(
          'T4 frobenius-norm $tag #$i',
          '${m.rpn} frobenius-norm',
          'chk(sqrt(sum(apply(x->x^2,flatten(${m.giacMatrix})))))',
        ),
      );
    }
  }

  // exp and ln: exact only on the zero matrix and the identity.
  for (final int n in <int>[1, 2, 3, 4]) {
    final _Operand zero = _Operand(
      _diagonal(List<BigInt>.filled(n, BigInt.zero)),
      BigInt.one,
    );
    final _Operand identity = _Operand(_integerIdentity(n), BigInt.one);
    final _Operand diagonal = _Operand(
      _diagonal(<BigInt>[
        for (int k = 0; k < n; k++) BigInt.from(g.nextInt(5) + 2),
      ]),
      BigInt.one,
    );
    cases
      ..add(
        _Case(
          'T4 exp zero ${n}x$n',
          '${zero.rpn} exp',
          'chk(exp(${zero.giacMatrix}))',
        ),
      )
      ..add(
        _Case(
          'T4 ln identity ${n}x$n',
          '${identity.rpn} ln',
          'chk(log(${identity.giacMatrix}))',
        ),
      )
      ..add(
        _Case(
          'T4 exp diagonal ${n}x$n',
          '${diagonal.rpn} exp',
          'chk(exp(${diagonal.giacMatrix}))',
        ),
      )
      ..add(
        _Case(
          'T4 ln diagonal ${n}x$n',
          '${diagonal.rpn} ln',
          'chk(log(${diagonal.giacMatrix}))',
        ),
      );
  }
}

List<String> _giacCommand() => Platform.isWindows
    ? <String>['wsl', '-d', 'Ubuntu', '--', 'giac']
    : <String>['giac'];

/// Runs every expression through one Giac process and returns its results
/// by index, or null when Giac cannot run here.
Future<Map<int, String>?> _runGiac(
  List<String> expressions, {
  List<String> prelude = const <String>[],
}) async {
  final List<String> command = _giacCommand();
  final Process process;
  try {
    process = await Process.start(command.first, command.sublist(1));
  } on ProcessException {
    return null;
  }
  // Giac's print writes to stderr; read both streams. Reading starts
  // before the input is written: with a large input, Giac fills the output
  // pipe while it still reads, and both sides would block.
  final Future<String> output = process.stdout
      .transform(const Utf8Decoder(allowMalformed: true))
      .join();
  final Future<String> errors = process.stderr
      .transform(const Utf8Decoder(allowMalformed: true))
      .join();
  final StringBuffer input = StringBuffer();
  prelude.forEach(input.writeln);
  for (int i = 0; i < expressions.length; i++) {
    input.writeln('print("R$i "+string(${expressions[i]}));');
  }
  // A command that starts but exits at once (`wsl` with no Ubuntu
  // distribution, as on the Windows CI runner) closes the pipe before the
  // input is written: Giac cannot run here either.
  try {
    process.stdin.write(input.toString());
    await process.stdin.close();
  } on IOException {
    await Future.wait(<Future<Object?>>[output, errors, process.exitCode]);
    return null;
  }
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
    giac = await _runGiac(
      cases.map((_Case c) => c.giac).toList(),
      prelude: _giacPrelude,
    );
  });

  test('Giac agrees with every exact result of steps T2 to T4', () {
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
    expect(cases.length, greaterThan(1000));
    int largest = 0;
    int irrational = 0;
    for (int i = 0; i < cases.length; i++) {
      final _Case c = cases[i];
      final String? theirs = giac![i];
      expect(theirs, isNotNull, reason: '${c.name}: no Giac result');
      if (theirs == _irrational) {
        // Not rational: an approximate result or an error, never exact.
        irrational++;
        try {
          final Matrix result = Calculatrix.evaluateRpn(
            Calculatrix.tokenizeRpnLine(c.rpn),
          );
          expect(result.isExact, isFalse, reason: '${c.name}: ${c.rpn}');
        } on CalculatrixError {
          // A value with no real result.
        }
        continue;
      }
      final Matrix result = Calculatrix.evaluateRpn(
        Calculatrix.tokenizeRpnLine(c.rpn),
      );
      expect(result.isExact, isTrue, reason: '${c.name}: ${c.rpn}');
      final List<String> ours = <String>[
        for (final List<Rational> row in result.exactRows)
          for (final Rational entry in row) _text(entry),
      ];
      for (final List<Rational> row in result.exactRows) {
        for (final Rational entry in row) {
          largest = math.max(largest, entry.digits);
        }
      }
      expect(ours, _giacEntries(theirs!), reason: '${c.name}: ${c.rpn}');
    }
    // The T4 cases reach both kinds of result.
    expect(irrational, greaterThan(40));
    // The cases reach results near the default limit of 10000 digits.
    expect(largest, greaterThan(9000));
  });
}
