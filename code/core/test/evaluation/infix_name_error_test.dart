// Infix has no notion of a function call or a bare name: it only accepts
// numbers, matrix literals, the five RPN operator symbols and parentheses.
// A name typed into infix (a call-like "sqrt(7)", or a bare "e") used to
// surface as an opaque "Unexpected token" pointing at just its first
// character. These tests cover the friendlier, actionable error instead:
// the message explains the limitation, and when the name is already a
// known RPN registry word or alias, shows the equivalent RPN form.

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('A name in infix explains the limitation', () {
    test('a registry word written as a call names itself and shows the '
        'RPN form', () {
      try {
        Calculatrix.evaluateInfix('sqrt(7)');
        fail('expected ExpressionSyntaxError');
      } on ExpressionSyntaxError catch (error) {
        expect(error.errorId, CalculatrixErrorId.syntaxError);
        expect(error.name, 'sqrt');
        expect(
          error.message,
          contains(
            'infix accepts numbers, matrix literals, + - * / ^ and parentheses',
          ),
        );
        expect(error.message, contains('"sqrt" is an RPN word'));
        expect(error.message, contains('cx eval rpn "7 sqrt"'));
      }
    });

    test('a second registry word, ln, shows its own RPN form', () {
      try {
        Calculatrix.evaluateInfix('ln(10)');
        fail('expected ExpressionSyntaxError');
      } on ExpressionSyntaxError catch (error) {
        expect(error.name, 'ln');
        expect(error.message, contains('"ln" is an RPN word'));
        expect(error.message, contains('cx eval rpn "10 ln"'));
      }
    });

    test('a third registry word, exp, with a decimal argument', () {
      try {
        Calculatrix.evaluateInfix('exp(1.5)');
        fail('expected ExpressionSyntaxError');
      } on ExpressionSyntaxError catch (error) {
        expect(error.name, 'exp');
        expect(error.message, contains('"exp" is an RPN word'));
        expect(error.message, contains('cx eval rpn "1.5 exp"'));
      }
    });

    test('an alias (not the entry\'s own name) still resolves to a word', () {
      try {
        // "root" is not registered as a word of its own; this exercises a
        // name that simply is not in the registry at all, same as "e"
        // below, rather than an alias (the registry has no alias for sqrt
        // other than its symbol, which cannot appear here as a name).
        Calculatrix.evaluateInfix('root(9)');
        fail('expected ExpressionSyntaxError');
      } on ExpressionSyntaxError catch (error) {
        expect(error.name, 'root');
        expect(error.message, isNot(contains('is an RPN word')));
        expect(error.message, contains('"root" is a name, not a number'));
      }
    });

    test('a bare name with no registry match explains the limitation '
        'without an RPN form', () {
      try {
        Calculatrix.evaluateInfix('e');
        fail('expected ExpressionSyntaxError');
      } on ExpressionSyntaxError catch (error) {
        expect(error.errorId, CalculatrixErrorId.syntaxError);
        expect(error.name, 'e');
        expect(
          error.message,
          contains(
            'infix accepts numbers, matrix literals, + - * / ^ and parentheses',
          ),
        );
        expect(error.message, contains('"e" is a name, not a number'));
        expect(error.message, isNot(contains('RPN word')));
      }
    });

    test('a name used mid-expression still carries its own 1-based '
        'position', () {
      try {
        Calculatrix.evaluateInfix('1+sqrt(7)');
        fail('expected ExpressionSyntaxError');
      } on ExpressionSyntaxError catch (error) {
        expect(error.name, 'sqrt');
        expect(error.position, 3);
      }
    });

    test('a registry word with a hyphen is recognized as the whole word, '
        'not just the run of letters before the hyphen (issue #51, AC2)', () {
      try {
        Calculatrix.evaluateInfix('frobenius-norm(7)');
        fail('expected ExpressionSyntaxError');
      } on ExpressionSyntaxError catch (error) {
        expect(error.name, 'frobenius-norm');
        expect(error.message, contains('"frobenius-norm" is an RPN word'));
        expect(error.message, contains('cx eval rpn "7 frobenius-norm"'));
      }
    });

    test('a call whose argument is not a plain number gives a generic, '
        'non-runnable description instead of a failing command (issue #51, '
        'AC2: "sqrt(1+2)" used to suggest "cx eval rpn \\"1+2 sqrt\\"", '
        'which fails as unknown-word)', () {
      try {
        Calculatrix.evaluateInfix('sqrt(1+2)');
        fail('expected ExpressionSyntaxError');
      } on ExpressionSyntaxError catch (error) {
        expect(error.name, 'sqrt');
        expect(error.message, isNot(contains('cx eval rpn')));
        expect(
          error.message,
          contains('in RPN the argument comes first: x sqrt'),
        );
      }
    });

    test('a space before the call parenthesis is not call-like, so it also '
        'gets the generic form instead of a failing command (issue #51, AC2: '
        '"sqrt (7)" used to suggest "cx eval rpn \\"sqrt\\"", which '
        'underflows)', () {
      try {
        Calculatrix.evaluateInfix('sqrt (7)');
        fail('expected ExpressionSyntaxError');
      } on ExpressionSyntaxError catch (error) {
        expect(error.name, 'sqrt');
        expect(error.message, isNot(contains('cx eval rpn')));
        expect(
          error.message,
          contains('in RPN the argument comes first: x sqrt'),
        );
      }
    });

    test(
      'a truncated call never crashes, for a range of truncation points '
      '(issue #51, AC1: "sqrt(" used to throw an unhandled RangeError '
      'instead of a normal syntax error)',
      () {
        for (final expression in <String>[
          'sqrt',
          'sqrt(',
          'sqrt( ',
          '(',
          'e(',
        ]) {
          try {
            Calculatrix.evaluateInfix(expression);
            fail('expected ExpressionSyntaxError for "$expression"');
          } on ExpressionSyntaxError catch (error) {
            expect(
              error.errorId,
              CalculatrixErrorId.syntaxError,
              reason: 'for "$expression"',
            );
          }
        }
      },
    );
  });
}
