// Issue #70 (runbook-agent-usability.md D66, step U5): the constants pi, e
// and i in RPN, in infix, and the lexing rules around them.
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

List<Matrix> _rpn(String program) =>
    Calculatrix.evaluateRpnStack(Calculatrix.tokenizeRpnLine(program));

String _text(Matrix value) => MatrixDisplayFormatter.text(value);

T _error<T extends CalculatrixError>(void Function() action) {
  try {
    action();
  } on T catch (error) {
    return error;
  }
  fail('expected $T');
}

void main() {
  group('RPN', () {
    test('pi equals math.pi, approximate', () {
      final Matrix value = _rpn('pi').single;
      expect(value.at(0, 0), math.pi);
      expect(value.isExact, isFalse);
      expect(_text(value), '~3.14159265359');
    });

    test('π is the alias of pi', () {
      expect(_rpn('π').single.at(0, 0), math.pi);
    });

    test('e equals math.e, approximate', () {
      final Matrix value = _rpn('e').single;
      expect(value.at(0, 0), math.e);
      expect(value.isExact, isFalse);
      expect(_text(value), '~2.71828182846');
    });

    test('i is exact [[0 -1] [1 0]]', () {
      final Matrix value = _rpn('i').single;
      expect(value.isExact, isTrue);
      expect(_text(value), '[[0 -1] [1 0]]');
    });

    test('names are case-insensitive', () {
      expect(_rpn('PI').single.at(0, 0), math.pi);
      expect(_rpn('E').single.at(0, 0), math.e);
      expect(_text(_rpn('I').single), '[[0 -1] [1 0]]');
    });

    test('i dup * is exact -1', () {
      final Matrix value = _rpn('i dup *').single;
      expect(value.isExact, isTrue);
      expect(_text(value), '[[-1 0] [0 -1]]');
    });

    test('3 4 i * + is exact [[3 -4] [4 3]]', () {
      final Matrix value = _rpn('3 4 i * +').single;
      expect(value.isExact, isTrue);
      expect(_text(value), '[[3 -4] [4 3]]');
    });

    test('a constant inside a program with other words', () {
      expect(_rpn('pi 2 *').single.at(0, 0), 2 * math.pi);
    });

    test('1e3 and 1E3 stay the number 1000', () {
      expect(_text(_rpn('1e3').single), '1000');
      expect(_text(_rpn('1E3').single), '1000');
    });

    test('2e and e3 stay unknown-word', () {
      for (final String token in <String>['2e', 'e3']) {
        final UnknownWordError error = _error(() => _rpn(token));
        expect(error.errorId, CalculatrixErrorId.unknownWord);
        expect(error.token, token);
      }
    });

    test('-pi, -e, -i, -π say how to negate', () {
      for (final String name in <String>['pi', 'e', 'i', 'π']) {
        final UnknownWordError error = _error(() => _rpn('-$name'));
        expect(error.errorId, CalculatrixErrorId.unknownWord);
        expect(error.token, '-$name');
        expect(
          error.message,
          '"-" is not part of a name; to negate it: $name negate',
        );
        expect(error.suggestions, isEmpty);
      }
    });

    test('~pi, ~e, ~i, ~π say how to make them approximate', () {
      for (final String name in <String>['pi', 'e', 'i', 'π']) {
        final UnknownWordError error = _error(() => _rpn('~$name'));
        expect(error.errorId, CalculatrixErrorId.unknownWord);
        expect(error.token, '~$name');
        expect(
          error.message,
          '"~" marks numeric literals only; to make it approximate: '
          '$name approx',
        );
        expect(error.suggestions, isEmpty);
      }
    });

    test('the advice of -pi and ~i runs', () {
      expect(_rpn('pi negate').single.at(0, 0), -math.pi);
      expect(_text(_rpn('i approx').single), '~[[0 -1] [1 0]]');
    });

    test('-x for a name that is not a constant keeps the usual message', () {
      final UnknownWordError error = _error(() => _rpn('-x'));
      expect(error.message, startsWith('Unknown word: -x.'));
    });

    test('the position of a rejected token is reported', () {
      final UnknownWordError error = _error(() => _rpn('1 -pi'));
      expect(error.position, 3);
    });
  });

  group('matrix literals', () {
    test('[[pi 0] [0 1]] is a syntax error naming the constant', () {
      final ExpressionSyntaxError error = _error(() => _rpn('[[pi 0] [0 1]]'));
      expect(error.errorId, CalculatrixErrorId.syntaxError);
      expect(
        error.message,
        'Invalid matrix literal: [[pi 0] [0 1]]; entries must be numbers, '
        '"pi" is a constant',
      );
    });

    test('the constant is named as typed, in a later entry too', () {
      final ExpressionSyntaxError error = _error(() => _rpn('[[1 π] [0 1]]'));
      expect(
        error.message,
        'Invalid matrix literal: [[1 π] [0 1]]; entries must be numbers, '
        '"π" is a constant',
      );
    });

    test('1e3 inside a literal is still a number', () {
      expect(_text(_rpn('[[1e3 0] [0 1]]').single), '[[1000 0] [0 1]]');
    });

    test('a literal with a name that is not a constant keeps its message', () {
      final ExpressionSyntaxError error = _error(() => _rpn('[[1 x] [3 4]]'));
      expect(error.message, 'Invalid matrix literal: [[1 x] [3 4]]');
    });

    test('the same message in infix', () {
      final ExpressionSyntaxError error = _error(
        () => Calculatrix.evaluateInfix('[[pi 0] [0 1]]'),
      );
      expect(
        error.message,
        'Invalid matrix literal: [[pi 0] [0 1]]; entries must be numbers, '
        '"pi" is a constant',
      );
    });
  });

  group('infix', () {
    test('2*pi', () {
      expect(Calculatrix.evaluateInfix('2*pi').at(0, 0), 2 * math.pi);
    });

    test('names are case-insensitive and π works', () {
      expect(Calculatrix.evaluateInfix('2*PI').at(0, 0), 2 * math.pi);
      expect(Calculatrix.evaluateInfix('2*π').at(0, 0), 2 * math.pi);
    });

    test('-pi is a unary minus', () {
      expect(Calculatrix.evaluateInfix('-pi').at(0, 0), -math.pi);
      expect(Calculatrix.evaluateInfix('-e').at(0, 0), -math.e);
    });

    test('3+4*i is exact [[3 -4] [4 3]]', () {
      final Matrix value = Calculatrix.evaluateInfix('3+4*i');
      expect(value.isExact, isTrue);
      expect(_text(value), '[[3 -4] [4 3]]');
    });

    test('i*i is exact -1', () {
      final Matrix value = Calculatrix.evaluateInfix('i*i');
      expect(value.isExact, isTrue);
      expect(_text(value), '[[-1 0] [0 -1]]');
    });

    test('e^(i*pi) is -1 within 1e-14', () {
      final Matrix value = Calculatrix.evaluateInfix('e^(i*pi)');
      final List<List<double>> expected = <List<double>>[
        <double>[-1, 0],
        <double>[0, -1],
      ];
      for (int r = 0; r < 2; r++) {
        for (int c = 0; c < 2; c++) {
          expect(value.at(r, c), closeTo(expected[r][c], 1e-14));
        }
      }
    });

    test('a constant minus a constant is two names, not one hyphenated', () {
      expect(Calculatrix.evaluateInfix('pi-e').at(0, 0), math.pi - math.e);
    });

    test('1e3 stays 1000', () {
      expect(_text(Calculatrix.evaluateInfix('1e3')), '1000');
    });

    test('2e stays a syntax error', () {
      final ExpressionSyntaxError error = _error(
        () => Calculatrix.evaluateInfix('2e'),
      );
      expect(error.errorId, CalculatrixErrorId.syntaxError);
      expect(error.message, 'Invalid numeric literal: 2e');
    });

    test('e3 and pi2 are names, not numbers', () {
      for (final String name in <String>['e3', 'pi2']) {
        final ExpressionSyntaxError error = _error(
          () => Calculatrix.evaluateInfix(name),
        );
        expect(error.message, contains('"$name" is a name, not a number'));
      }
    });

    test('a name that is an RPN word keeps the U4 error', () {
      final ExpressionSyntaxError error = _error(
        () => Calculatrix.evaluateInfix('sqrt(4)'),
      );
      expect(error.message, contains('"sqrt" is an RPN word'));
    });

    test('any other name keeps the "is a name" error', () {
      final ExpressionSyntaxError error = _error(
        () => Calculatrix.evaluateInfix('x+1'),
      );
      expect(error.message, contains('"x" is a name, not a number'));
    });

    test('2pi has no implicit product', () {
      final ExpressionSyntaxError error = _error(
        () => Calculatrix.evaluateInfix('2pi'),
      );
      expect(error.errorId, CalculatrixErrorId.syntaxError);
    });
  });
}
