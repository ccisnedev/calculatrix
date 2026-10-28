// A repeated eigenvalue of a diagonalizable matrix gets a basis of its
// eigenspace, so P is invertible and P D P⁻¹ = A. A defective matrix has
// no such basis: diagonalize raises not-diagonalizable, never a singular P.

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

Matrix _m(List<List<double>> rows) => Matrix(rows);

void _expectClose(Matrix actual, Matrix expected, {double tolerance = 1e-9}) {
  expect(actual.rowCount, expected.rowCount);
  expect(actual.columnCount, expected.columnCount);
  for (int r = 0; r < expected.rowCount; r++) {
    for (int c = 0; c < expected.columnCount; c++) {
      expect(
        actual.at(r, c),
        closeTo(expected.at(r, c), tolerance),
        reason: 'entry ($r, $c)',
      );
    }
  }
}

void _expectReconstructs(Matrix a) {
  final Diagonalization result = a.diagonalization();
  _expectClose(result.p * result.d * result.p.inverse(), a);
}

final Matcher _notDiagonalizable = throwsA(
  isA<MatrixDomainError>().having(
    (MatrixDomainError error) => error.errorId,
    'errorId',
    CalculatrixErrorId.notDiagonalizable,
  ),
);

void main() {
  group('diagonalize with a repeated eigenvalue', () {
    test('2I gives an invertible P and D = 2I', () {
      final Diagonalization result = _m(<List<double>>[
        <double>[2, 0],
        <double>[0, 2],
      ]).diagonalization();
      _expectClose(
        result.d,
        _m(<List<double>>[
          <double>[2, 0],
          <double>[0, 2],
        ]),
      );
      expect(result.p.rank().scalarValue, 2);
      _expectReconstructs(
        _m(<List<double>>[
          <double>[2, 0],
          <double>[0, 2],
        ]),
      );
    });

    test('diag(2, 2, 3) reconstructs', () {
      _expectReconstructs(
        _m(<List<double>>[
          <double>[2, 0, 0],
          <double>[0, 2, 0],
          <double>[0, 0, 3],
        ]),
      );
    });

    test('a non-diagonal matrix with eigenvalues 4, 1, 1 reconstructs', () {
      _expectReconstructs(
        _m(<List<double>>[
          <double>[2, 1, 1],
          <double>[1, 2, 1],
          <double>[1, 1, 2],
        ]),
      );
    });

    test(
      'a non-symmetric 2x2 with distinct eigenvalues still reconstructs',
      () {
        _expectReconstructs(
          _m(<List<double>>[
            <double>[2, 1],
            <double>[0, 3],
          ]),
        );
      },
    );
  });

  group('diagonalize of a defective matrix', () {
    test('the 2x2 Jordan block raises not-diagonalizable', () {
      expect(
        () => _m(<List<double>>[
          <double>[1, 1],
          <double>[0, 1],
        ]).diagonalization(),
        _notDiagonalizable,
      );
    });

    test('a 3x3 Jordan block raises not-diagonalizable', () {
      expect(
        () => _m(<List<double>>[
          <double>[2, 1, 0],
          <double>[0, 2, 0],
          <double>[0, 0, 3],
        ]).diagonalization(),
        _notDiagonalizable,
      );
    });

    test('the word raises not-diagonalizable at its token', () {
      expect(
        () => Calculatrix.evaluateRpn(
          Calculatrix.tokenizeRpnLine('[[1 1] [0 1]] diagonalize'),
        ),
        throwsA(
          isA<MatrixDomainError>()
              .having(
                (MatrixDomainError error) => error.errorId,
                'errorId',
                CalculatrixErrorId.notDiagonalizable,
              )
              .having((MatrixDomainError e) => e.token, 'token', 'diagonalize'),
        ),
      );
    });

    test('the registry lists not-diagonalizable for diagonalize', () {
      expect(
        CalculatrixCommandRegistry.standard.lookup('diagonalize')!.errors,
        contains(CalculatrixErrorId.notDiagonalizable),
      );
    });
  });

  group('words built on diagonalization', () {
    test('ln of diag(2, 2, 3) is diag(ln 2, ln 2, ln 3)', () {
      final Matrix result = Calculatrix.evaluateRpn(
        Calculatrix.tokenizeRpnLine('[[2 0 0] [0 2 0] [0 0 3]] ln'),
      );
      _expectClose(
        result,
        _m(<List<double>>[
          <double>[0.6931471805599453, 0, 0],
          <double>[0, 0.6931471805599453, 0],
          <double>[0, 0, 1.0986122886681098],
        ]),
      );
    });

    test('ln of a matrix with eigenvalues 4, 1, 1 inverts exp', () {
      final Matrix a = _m(<List<double>>[
        <double>[2, 1, 1],
        <double>[1, 2, 1],
        <double>[1, 1, 2],
      ]);
      _expectClose(a.log().exp(), a);
    });

    test('a non-integer power of diag(4, 4, 9) is exact up to rounding', () {
      final Matrix result = Calculatrix.evaluateRpn(
        Calculatrix.tokenizeRpnLine('[[4 0 0] [0 4 0] [0 0 9]] 1.5 ^'),
      );
      _expectClose(
        result,
        _m(<List<double>>[
          <double>[8, 0, 0],
          <double>[0, 8, 0],
          <double>[0, 0, 27],
        ]),
        tolerance: 1e-8,
      );
    });

    test('ln of a defective 3x3 raises not-diagonalizable, not a value', () {
      expect(
        () => Calculatrix.evaluateRpn(
          Calculatrix.tokenizeRpnLine('[[2 1 0] [0 2 0] [0 0 3]] ln'),
        ),
        _notDiagonalizable,
      );
    });

    test('the registry lists not-diagonalizable for ln and power', () {
      for (final String word in <String>['ln', 'power']) {
        expect(
          CalculatrixCommandRegistry.standard.lookup(word)!.errors,
          contains(CalculatrixErrorId.notDiagonalizable),
          reason: word,
        );
      }
    });
  });
}
