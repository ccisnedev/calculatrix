// The principal square root, or a non-integer power, of a matrix with a
// negative real eigenvalue is complex: it raises complex-result, not a
// convergence failure. A negative scalar keeps its complex form.

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

Matcher _complexRoot(String token) => throwsA(
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
        allOf(contains('complex'), isNot(contains('converge'))),
      ),
);

Matrix _run(String program) =>
    Calculatrix.evaluateRpn(Calculatrix.tokenizeRpnLine(program));

void main() {
  group('a negative real eigenvalue gives complex-result', () {
    for (final String program in <String>[
      '[[-1 0] [0 2]] sqrt',
      '[[-1 0] [0 2]] 0.5 ^',
      '[[-1 0] [0 2]] 1.5 ^',
      '[[-1 0 0] [0 2 0] [0 0 3]] sqrt',
      '[[-1 0 0] [0 2 0] [0 0 3]] 2.5 ^',
    ]) {
      test(program, () {
        expect(() => _run(program), _complexRoot(program.split(' ').last));
      });
    }

    test('the registry lists complex-result for sqrt and power', () {
      for (final String word in <String>['sqrt', 'power']) {
        expect(
          CalculatrixCommandRegistry.standard.lookup(word)!.errors,
          contains(CalculatrixErrorId.complexResult),
          reason: word,
        );
      }
    });
  });

  group('unchanged', () {
    test('-4 0.5 ^ is the complex form of 2i', () {
      expect(_run('-4 0.5 ^').toString(), _run('[[0 -2] [2 0]]').toString());
    });

    test('a positive spectrum keeps its real root', () {
      final Matrix root = _run('[[4 0] [0 9]] sqrt');
      expect(root.at(0, 0), closeTo(2, 1e-12));
      expect(root.at(1, 1), closeTo(3, 1e-12));
    });
  });
}
