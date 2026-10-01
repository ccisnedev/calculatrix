// The stack-underflow message used to read "Cannot pop from an empty RPN
// stack.", an engine-internal sentence that named neither the word the
// caller typed nor how far short the stack fell. Once the evaluator's
// dispatch loop enriches the error with the word that triggered it (see
// Calculatrix._executePositioned / CalculatrixError.enrichToken), the
// message is rebuilt from that word plus the needed/found counts recorded
// at the engine throw site. The id, and everything error_id_wiring_test
// and token_position_test already assert, are unchanged.

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('RpnStackUnderflowError.message names the word and the counts', () {
    test('a binary operator on an empty stack states both counts', () {
      try {
        Calculatrix.evaluateRpn(<String>['+']);
        fail('expected RpnStackUnderflowError');
      } on RpnStackUnderflowError catch (error) {
        expect(error.errorId, CalculatrixErrorId.stackUnderflow);
        expect(error.message, '+ needs 2 values on the stack, found 0.');
      }
    });

    test('a binary operator with one operand already there counts it', () {
      try {
        Calculatrix.evaluateRpn(<String>['5', '+']);
        fail('expected RpnStackUnderflowError');
      } on RpnStackUnderflowError catch (error) {
        expect(error.message, '+ needs 2 values on the stack, found 1.');
      }
    });

    test('drop on an empty stack names itself', () {
      try {
        Calculatrix.evaluateRpn(<String>['drop']);
        fail('expected RpnStackUnderflowError');
      } on RpnStackUnderflowError catch (error) {
        expect(error.message, 'drop needs 1 value on the stack, found 0.');
      }
    });

    test('an error built with no token falls back to its own message '
        '(the engine threw it, but nothing has enriched it yet)', () {
      final error = RpnStackUnderflowError(
        'Cannot pop from an empty RPN stack.',
        errorId: CalculatrixErrorId.stackUnderflow,
        needed: 1,
        found: 0,
      );

      expect(error.message, 'Cannot pop from an empty RPN stack.');
    });

    test('a RpnStackUnderflowError without needed/found keeps its '
        'original message once a token is attached, same as before this '
        'change', () {
      final error = RpnStackUnderflowError(
        'Stack index 2 exceeds current depth 1.',
        errorId: CalculatrixErrorId.stackUnderflow,
      )..enrichToken('roll', 1);

      expect(error.message, 'Stack index 2 exceeds current depth 1.');
    });
  });
}
