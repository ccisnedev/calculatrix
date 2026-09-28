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

  group('A postfix operator after a bare function argument is not a syntax '
      'error (issue #5 review round 1, finding 5)', () {
    // Unlike a further binary operator or function (ambiguous about how
    // much of the expression the bare function's argument covers), a
    // postfix operator such as "%" applies unambiguously to whatever
    // value already resolved the pending bare function: "(root 0)%" and
    // "root 0 %" mean the same thing either way. This must keep matching
    // origin/main's behavior, which predates the bare-function guard.
    test('a postfix operator after a bare function argument is valid', () {
      final Matrix result = Calculatrix.evaluateInfix('√0%');
      expect(result, Matrix.scalar(0));
    });

    test('a postfix operator after a bare function argument of a non-zero '
        'root is valid', () {
      final Matrix result = Calculatrix.evaluateInfix('√9%');
      expect(result, Matrix.scalar(0.3));
    });

    test(
      'a postfix operator after nested bare function arguments is valid',
      () {
        final Matrix result = Calculatrix.evaluateInfix('√√(16)%');
        expect(result, Matrix.scalar(0.2));
      },
    );

    test('a bare function argument followed by a binary operator is still a '
        'syntax error', () {
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
      // RPN's token compiler parses the whole token with double.tryParse,
      // which recognizes "NaN", so this is where the non-finite guard for
      // it applies.
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

    test('an infix NaN literal is non-finite, not syntax-error', () {
      // The infix tokenizer does not scan a letter-led token as a number
      // through the ordinary digit-led numeric scan, but "NaN" is still a
      // recognized (non-finite) numeric literal (issue #5 bug 4): it must
      // reach the same non-finite guard as every other non-finite literal,
      // not raise syntax-error.
      expect(
        () => Calculatrix.evaluateInfix('NaN'),
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

  group('An empty matrix literal is dimension-mismatch, not syntax-error '
      '(issue #5 spec section 6)', () {
    test('RPN "[]" carries dimension-mismatch', () {
      // syntax-error is infix only (spec section 6): "[]" is well-formed
      // syntax that names an impossible shape, in both notations, so RPN
      // must report dimension-mismatch here too, not syntax-error.
      expect(
        () => Calculatrix.evaluateRpn(<String>['[]']),
        throwsA(
          isA<MatrixShapeError>().having(
            (MatrixShapeError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.dimensionMismatch,
          ),
        ),
      );
    });

    test('infix "[]" also carries dimension-mismatch', () {
      expect(
        () => Calculatrix.evaluateInfix('[]'),
        throwsA(
          isA<MatrixShapeError>().having(
            (MatrixShapeError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.dimensionMismatch,
          ),
        ),
      );
    });
  });
}
