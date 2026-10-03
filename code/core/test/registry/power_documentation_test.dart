// Issue #73 (runbook-agent-usability.md D67, step U4c): the registry
// documents when `power` is exact and when it is approximate.
import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  final CalculatrixCommandEntry power = CalculatrixCommandRegistry.standard
      .lookup('power')!;

  test('the description states the exactness rules', () {
    expect(
      power.description,
      'Raises B to the power Y. The result is exact when B and Y are exact '
      'and Y is an integer, or when Y is a fraction p/q and the root is '
      'rational; otherwise it is approximate, marked ~, computed as '
      'exp(Y . log B). Exponents -1 and 0.5 use the inverse and '
      'square-root algorithms; inverse and sqrt are defined in terms of '
      'this word.',
    );
  });

  final Map<String, String> documented = <String, String>{
    '2 -3 ^': '0.125',
    '8 1/3 ^': '2',
    '2 0.5 ^': '~1.41421356237',
  };

  documented.forEach((String program, String text) {
    test('documents "$program -> $text", and the program gives it', () {
      final CalculatrixCommandExample example = power.examples.singleWhere(
        (CalculatrixCommandExample e) => e.program == program,
      );
      expect(
        example.expectedStack.map(MatrixDisplayFormatter.text).toList(),
        <String>[text],
      );
      final List<Matrix> result = Calculatrix.evaluateRpnStack(
        Calculatrix.tokenizeRpnLine(program),
      );
      expect(result.map(MatrixDisplayFormatter.text).toList(), <String>[text]);
    });
  });
}
