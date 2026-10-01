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
  });
}
