// Issue #73 (runbook-agent-usability.md D68, step U4a): an infix call of an
// RPN word whose parentheses hold a comma-separated list of literals gets
// the exact RPN program to type. Any other argument keeps the generic
// message. Error id, position and name are unchanged.
import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

ExpressionSyntaxError _infixError(String expression) {
  try {
    Calculatrix.evaluateInfix(expression);
  } on ExpressionSyntaxError catch (error) {
    return error;
  }
  fail('expected ExpressionSyntaxError for $expression');
}

const String _generic = 'in RPN the argument comes first';

void main() {
  group('infix call of an RPN word with literal arguments (#73 a)', () {
    test('inverse([[1 2] [3 4]]) gives the matrix program', () {
      final error = _infixError('inverse([[1 2] [3 4]])');
      expect(error.errorId, CalculatrixErrorId.syntaxError);
      expect(error.name, 'inverse');
      expect(error.position, 1);
      expect(
        error.message,
        endsWith(
          '"inverse" is an RPN word: '
          'cx eval rpn "[[1 2] [3 4]] inverse"',
        ),
      );
    });

    test('determinant([[2 0] [0 3]])', () {
      expect(
        _infixError('determinant([[2 0] [0 3]])').message,
        endsWith('cx eval rpn "[[2 0] [0 3]] determinant"'),
      );
    });

    test('power(2, 3) lists both arguments before the word', () {
      final error = _infixError('power(2, 3)');
      expect(error.name, 'power');
      expect(error.message, endsWith('cx eval rpn "2 3 power"'));
    });

    test('negative and approximate literals are copied verbatim', () {
      expect(
        _infixError('power(~2, -3)').message,
        endsWith('cx eval rpn "~2 -3 power"'),
      );
      expect(
        _infixError('inverse(~[[1 2] [3 4]])').message,
        endsWith('cx eval rpn "~[[1 2] [3 4]] inverse"'),
      );
    });

    test('a comma inside a matrix literal does not split the arguments', () {
      expect(
        _infixError('inverse([[1,2],[3,4]])').message,
        endsWith('cx eval rpn "[[1,2],[3,4]] inverse"'),
      );
    });

    test('the position of the name is kept mid-expression', () {
      final error = _infixError('1+power(2, 3)');
      expect(error.position, 3);
      expect(error.message, endsWith('cx eval rpn "2 3 power"'));
    });

    test('an expression argument keeps the generic message', () {
      final error = _infixError('inverse(2+3)');
      expect(error.message, contains(_generic));
      expect(error.message, isNot(contains('cx eval rpn')));
    });

    test('a list with one expression keeps the generic message', () {
      expect(_infixError('power(2, 1+2)').message, contains(_generic));
    });

    test('an empty argument, an empty element and unbalanced parentheses '
        'keep the generic message', () {
      expect(_infixError('inverse()').message, contains(_generic));
      expect(_infixError('power(2,)').message, contains(_generic));
      expect(_infixError('power(2, 3').message, contains(_generic));
    });

    test('sqrt(7) is unchanged', () {
      expect(
        _infixError('sqrt(7)').message,
        endsWith('"sqrt" is an RPN word: cx eval rpn "7 sqrt"'),
      );
    });
  });
}
