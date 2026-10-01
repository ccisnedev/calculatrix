// complex-result (runbook-trust.md D60): a real matrix whose eigenvalues
// include a complex pair has no column of eigenvalues to return yet (issue
// #64), so `eigenvalues` and `diagonalize` raise their own id instead of a
// generic error, exact or approximate.

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

Matcher _complexResult(String token) => throwsA(
  isA<MatrixDomainError>()
      .having(
        (MatrixDomainError error) => error.errorId,
        'errorId',
        CalculatrixErrorId.complexResult,
      )
      .having((MatrixDomainError error) => error.token, 'token', token)
      .having(
        (MatrixDomainError error) => error.message,
        'message',
        'The eigenvalues of this matrix are complex, and cx has no complex '
            'columns yet.',
      ),
);

void main() {
  group('complex-result (D60)', () {
    for (final String program in <String>[
      // The rotation of trap 8, exact and approximate.
      '[[0 -1] [1 0]] eigenvalues',
      '[[0 -1] [1 0]] approx eigenvalues',
      '[[0 -1] [1 0]] eig',
      // The pair is the last 2x2 block of the QR iteration.
      '[[0 -1 0] [1 0 0] [0 0 2]] eigenvalues',
      // The pair deflates as a 2x2 block inside a larger matrix.
      '[[2 0 0 0] [0 3 0 0] [0 0 0 -1] [0 0 1 0]] eigenvalues',
    ]) {
      test(program, () {
        final String token = program.split(' ').last;
        expect(
          () => Calculatrix.evaluateRpn(Calculatrix.tokenizeRpnLine(program)),
          _complexResult(token),
        );
      });
    }

    test('diagonalize', () {
      expect(
        () => Calculatrix.evaluateRpn(
          Calculatrix.tokenizeRpnLine('[[0 -1] [1 0]] diagonalize'),
        ),
        _complexResult('diagonalize'),
      );
    });

    test('a real spectrum is unchanged', () {
      expect(
        Calculatrix.evaluateRpn(
          Calculatrix.tokenizeRpnLine('[[2 1] [1 2]] eigenvalues'),
        ).toString(),
        Calculatrix.evaluateRpn(
          Calculatrix.tokenizeRpnLine('[[3] [1]]'),
        ).toString(),
      );
    });

    test('the logarithm keeps its generic error: a rotation has a real '
        'logarithm, so complex-result would be wrong there', () {
      expect(
        () => Calculatrix.evaluateRpn(
          Calculatrix.tokenizeRpnLine('[[0 -1 0] [1 0 0] [0 0 2]] ln'),
        ),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError error) => error.errorId,
            'errorId',
            isNull,
          ),
        ),
      );
    });
  });
}
