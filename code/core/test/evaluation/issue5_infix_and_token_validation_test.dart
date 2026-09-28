// Tests for issue #5's remaining bugs (spec section 1):
//   bug 2: infix accepts invalid syntax ("1 2 +", "1()", "root9+7" all
//   silently evaluated instead of raising syntax-error).
//   bug 3 (RPN half): an unrecognized RPN word must raise unknown-word,
//   never silently fall back to the infix evaluator (the CLI half of bug 3
//   is covered by code/cli/test/calculatrix_cli_test.dart).
//   bug 4: non-finite numeric literals (1e999, NaN) must raise a
//   non-finite domain error instead of crashing downstream.

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('Infix syntax validation (issue #5 bug 2)', () {
    test('two operands with no operator between them is a syntax error', () {
      // "1 2 +" must not silently evaluate to 3.
      expect(
        () => Calculatrix.evaluateInfix('1 2 +'),
        throwsA(
          isA<ExpressionSyntaxError>().having(
            (ExpressionSyntaxError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.syntaxError,
          ),
        ),
      );
    });

    test('empty parentheses are not a valid operand', () {
      // "1()" must not silently evaluate to 1.
      expect(
        () => Calculatrix.evaluateInfix('1()'),
        throwsA(
          isA<ExpressionSyntaxError>().having(
            (ExpressionSyntaxError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.syntaxError,
          ),
        ),
      );
    });

    test(
      'a bare function argument followed by an operator is a syntax error',
      () {
        // "root9+7" must not silently evaluate to root(9+7) = 4.
        expect(
          () => Calculatrix.evaluateInfix('√9+7'),
          throwsA(
            isA<ExpressionSyntaxError>().having(
              (ExpressionSyntaxError error) => error.errorId,
              'errorId',
              CalculatrixErrorId.syntaxError,
            ),
          ),
        );
      },
    );

    test('parenthesizing the bare function argument makes it valid', () {
      final Matrix result = Calculatrix.evaluateInfix('(√9)+7');
      expect(result, Matrix.scalar(10));
    });

    test('nested bare function arguments are also a syntax error (case H)', () {
      expect(
        () => Calculatrix.evaluateInfix('√√(16)+1'),
        throwsA(
          isA<ExpressionSyntaxError>().having(
            (ExpressionSyntaxError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.syntaxError,
          ),
        ),
      );
    });
  });

  group('Non-finite literals are rejected (issue #5 bug 4)', () {
    test(
      'an infix numeric literal that overflows to infinity is non-finite',
      () {
        expect(
          () => Calculatrix.evaluateInfix('1e999'),
          throwsA(
            isA<MatrixDomainError>().having(
              (MatrixDomainError error) => error.errorId,
              'errorId',
              CalculatrixErrorId.nonFinite,
            ),
          ),
        );
      },
    );

    test('an RPN NaN literal is non-finite', () {
      // The infix tokenizer never scans a letter-led token as a number (it
      // only starts a numeric scan on a digit, a dot, or a signed digit),
      // so infix "NaN" is not a valid numeric literal to begin with; it
      // correctly raises syntax-error, covered by the tokenizer tests
      // above. RPN's token compiler instead parses the whole token with
      // double.tryParse, which does recognize "NaN", so this is where the
      // non-finite guard for it applies.
      expect(
        () => Calculatrix.evaluateRpn(<String>['NaN']),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.nonFinite,
          ),
        ),
      );
    });

    test('an RPN numeric literal that overflows to infinity is non-finite', () {
      expect(
        () => Calculatrix.evaluateRpn(<String>['1e999']),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.nonFinite,
          ),
        ),
      );
    });

    test('a matrix literal containing a non-finite entry is non-finite', () {
      expect(
        () => Calculatrix.evaluateInfix('[[1, 1e999]]'),
        throwsA(
          isA<MatrixDomainError>().having(
            (MatrixDomainError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.nonFinite,
          ),
        ),
      );
    });
  });

  group(
    'RPN never falls back to infix for an unknown word (issue #5 bug 3)',
    () {
      test('an unrecognized RPN token raises unknown-word', () {
        expect(
          () => Calculatrix.evaluateRpn(<String>['banana']),
          throwsA(
            isA<UnknownWordError>().having(
              (UnknownWordError error) => error.errorId,
              'errorId',
              CalculatrixErrorId.unknownWord,
            ),
          ),
        );
      });
    },
  );

  group('The ^ operator (issue #5)', () {
    test('binds tighter than * and is right associative', () {
      // 2 ^ 3 ^ 2 == 2 ^ (3 ^ 2) == 2 ^ 9 == 512, not (2 ^ 3) ^ 2 == 64.
      final Matrix result = Calculatrix.evaluateInfix('2 ^ 3 ^ 2');
      expect(result, Matrix.scalar(512));
    });

    test('evaluates a matrix power through infix', () {
      final Matrix result = Calculatrix.evaluateInfix('[[1,1],[0,1]] ^ 3');
      expect(
        result,
        Matrix(<List<double>>[
          <double>[1, 3],
          <double>[0, 1],
        ]),
      );
    });

    test('evaluates a matrix power through RPN', () {
      final Matrix result = Calculatrix.evaluateRpn(<String>[
        '[[1,1],[0,1]]',
        '3',
        '^',
      ]);
      expect(
        result,
        Matrix(<List<double>>[
          <double>[1, 3],
          <double>[0, 1],
        ]),
      );
    });
  });
}
