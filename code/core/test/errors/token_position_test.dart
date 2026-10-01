// Tests for issue #5 review round 1, finding 1: every domain error whose
// cause traces back to an input token must carry that token and its
// 1-based character position in the source program (spec section 2), not
// just the token in isolation. For RPN this is the character offset of the
// token within `tokens.join(' ')` (the same string Calculatrix reports as
// the evaluated expression); for infix it is the offset of the offending
// token within the raw expression string.

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

// Mirrors evaluateRpn's own position convention (1-based offset within
// tokens.join(' ')) as an independent check, so the test does not simply
// restate whatever the implementation itself computed.
int _expectedRpnPosition(List<String> tokens, int index) {
  int position = 1;
  for (int i = 0; i < index; i++) {
    position += tokens[i].length + 1;
  }
  return position;
}

void main() {
  group('RPN domain errors carry token and position (issue #5 section 2)', () {
    test(
      'unknown-word: an unrecognized word carries itself and position 1',
      () {
        try {
          Calculatrix.evaluateRpn(<String>['bogus']);
          fail('expected UnknownWordError');
        } on UnknownWordError catch (error) {
          expect(error.errorId, CalculatrixErrorId.unknownWord);
          expect(error.token, 'bogus');
          expect(error.position, 1);
        }
      },
    );

    test('stack-underflow: a binary operator with no operands carries itself '
        'and position 1', () {
      try {
        Calculatrix.evaluateRpn(<String>['+']);
        fail('expected RpnStackUnderflowError');
      } on RpnStackUnderflowError catch (error) {
        expect(error.errorId, CalculatrixErrorId.stackUnderflow);
        expect(error.token, '+');
        expect(error.position, 1);
      }
    });

    test('type-mismatch: dividing by a non-scalar carries the "/" token', () {
      final List<String> tokens = <String>['1', '[[1,2]]', '/'];
      try {
        Calculatrix.evaluateRpn(tokens);
        fail('expected UnsupportedCalculatrixOperationError');
      } on UnsupportedCalculatrixOperationError catch (error) {
        expect(error.errorId, CalculatrixErrorId.typeMismatch);
        expect(error.token, '/');
        expect(error.position, _expectedRpnPosition(tokens, 2));
      }
    });

    test('dimension-mismatch: mismatched addition carries the "+" token', () {
      final List<String> tokens = <String>['[[1,2]]', '[[1,2,3]]', '+'];
      try {
        Calculatrix.evaluateRpn(tokens);
        fail('expected MatrixShapeError');
      } on MatrixShapeError catch (error) {
        expect(error.errorId, CalculatrixErrorId.dimensionMismatch);
        expect(error.token, '+');
        expect(error.position, _expectedRpnPosition(tokens, 2));
      }
    });

    test('singular-matrix: inverting via a -1 power carries the "^" token', () {
      final List<String> tokens = <String>['[[1,2],[2,4]]', '-1', '^'];
      try {
        Calculatrix.evaluateRpn(tokens);
        fail('expected MatrixDomainError');
      } on MatrixDomainError catch (error) {
        expect(error.errorId, CalculatrixErrorId.singularMatrix);
        expect(error.token, '^');
        expect(error.position, _expectedRpnPosition(tokens, 2));
      }
    });

    test(
      'non-finite: an overflowing literal carries itself and position 1',
      () {
        try {
          Calculatrix.evaluateRpn(<String>['1e999']);
          fail('expected MatrixDomainError');
        } on MatrixDomainError catch (error) {
          expect(error.errorId, CalculatrixErrorId.nonFinite);
          expect(error.token, '1e999');
          expect(error.position, 1);
        }
      },
    );

    test('non-finite: an overflowing product carries the "*" token, and '
        'the whole stack is checked the same way', () {
      for (final List<String> tokens in <List<String>>[
        <String>['1e300', '1e300', '*'],
        <String>['[[1e300 1]]', '1e300', '*'],
      ]) {
        try {
          Calculatrix.evaluateRpnStack(tokens);
          fail('expected MatrixDomainError for $tokens');
        } on MatrixDomainError catch (error) {
          expect(error.errorId, CalculatrixErrorId.nonFinite);
          expect(error.token, '*');
          expect(error.position, tokens.join(' ').length);
        }
      }
    });

    test('non-finite: an overflowing infix product carries "*"', () {
      try {
        Calculatrix.evaluateInfix('1e300*1e300');
        fail('expected MatrixDomainError');
      } on MatrixDomainError catch (error) {
        expect(error.errorId, CalculatrixErrorId.nonFinite);
        expect(error.token, '*');
        expect(error.position, 6);
      }
    });

    test('log-undefined: a non-integer power of a matrix with a non-positive '
        'real eigenvalue carries the "^" token', () {
      final List<String> tokens = <String>['[[-1,0],[0,2]]', '0.5', '^'];
      try {
        Calculatrix.evaluateRpn(tokens);
        fail('expected MatrixDomainError');
      } on MatrixDomainError catch (error) {
        expect(error.errorId, CalculatrixErrorId.logUndefined);
        expect(error.token, '^');
        expect(error.position, _expectedRpnPosition(tokens, 2));
      }
    });

    test('ambiguous-power: a negative scalar base with a non-complex matrix '
        'exponent carries the "^" token', () {
      final List<String> tokens = <String>['-2', '[[1,2],[3,4]]', '^'];
      try {
        Calculatrix.evaluateRpn(tokens);
        fail('expected MatrixDomainError');
      } on MatrixDomainError catch (error) {
        expect(error.errorId, CalculatrixErrorId.ambiguousPower);
        expect(error.token, '^');
        expect(error.position, _expectedRpnPosition(tokens, 2));
      }
    });
  });

  group('Infix errors carry token and position (issue #5 section 2)', () {
    test('syntax-error carries the offending token and its 1-based offset', () {
      // "1 2 +": the second operand "2" is the offending token, at index 2
      // (0-based) in the string, i.e. 1-based position 3.
      try {
        Calculatrix.evaluateInfix('1 2 +');
        fail('expected ExpressionSyntaxError');
      } on ExpressionSyntaxError catch (error) {
        expect(error.errorId, CalculatrixErrorId.syntaxError);
        expect(error.token, '2');
        expect(error.position, 3);
      }
    });

    test('a domain error raised during infix evaluation carries the '
        'offending operator token and its 1-based offset', () {
      // "1/0": division by zero scalar is non-finite, raised once "/" is
      // dispatched; "/" sits at 0-based index 1, i.e. 1-based position 2.
      try {
        Calculatrix.evaluateInfix('1/0');
        fail('expected MatrixDomainError');
      } on MatrixDomainError catch (error) {
        expect(error.errorId, CalculatrixErrorId.nonFinite);
        expect(error.token, '/');
        expect(error.position, 2);
      }
    });

    test('leading whitespace in the original input line counts toward the '
        'offending token\'s 1-based offset (review round 1 follow-up)', () {
      // "  1/0": two leading spaces before "1/0", so "/" sits at 0-based
      // index 3 in the original line, i.e. 1-based position 4. The
      // expression must not be trimmed before positions are computed.
      try {
        Calculatrix.evaluateInfix('  1/0');
        fail('expected MatrixDomainError');
      } on MatrixDomainError catch (error) {
        expect(error.errorId, CalculatrixErrorId.nonFinite);
        expect(error.token, '/');
        expect(error.position, 4);
      }
    });
  });

  group('RPN positions count leading whitespace in the input line '
      '(review round 1 follow-up)', () {
    test('a raw token carrying leading whitespace still reports the '
        '1-based offset of the token itself, not of the whitespace', () {
      // A single raw token "  bogus" stands in for a caller that hands
      // evaluateRpn a token straight off an untrimmed input line: "bogus"
      // starts at 0-based index 2 within it, i.e. 1-based position 3.
      try {
        Calculatrix.evaluateRpn(<String>['  bogus']);
        fail('expected UnknownWordError');
      } on UnknownWordError catch (error) {
        expect(error.errorId, CalculatrixErrorId.unknownWord);
        expect(error.token, 'bogus');
        expect(error.position, 3);
      }
    });

    test('leading empty tokens (a leading run of whitespace in the joined '
        'input line) still report the correct 1-based offset', () {
      // tokens.join(' ') for ['', '', 'bogus'] is "  bogus", the same
      // input line as the test above, reached a different way.
      try {
        Calculatrix.evaluateRpn(<String>['', '', 'bogus']);
        fail('expected UnknownWordError');
      } on UnknownWordError catch (error) {
        expect(error.errorId, CalculatrixErrorId.unknownWord);
        expect(error.token, 'bogus');
        expect(error.position, 3);
      }
    });
  });
}
