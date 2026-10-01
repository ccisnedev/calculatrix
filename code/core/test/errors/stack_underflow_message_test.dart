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

    // A word such as "power" (arity 2) used to report "needs 1 value,
    // found 0" on an empty stack: PowerCommand popped its two operands one
    // at a time, so the first pop to fail only ever knew about itself, not
    // the word's real, user-facing arity. Worse, a defined word whose
    // program pushes a literal before calling such a primitive (e.g.
    // "sqrt" is "0.5 power") inflated the depth the primitive saw, so even
    // remapping the inner failure's own needed/found could not have fixed
    // every case. The fix checks the real, pre-expansion depth against the
    // word's own declared arity before any of its commands run (issue #51,
    // AC5), so this walks every word the registry declares an arity for
    // and checks both an empty stack and a stack one value short of it.
    test('every registry word with a declared arity reports that arity '
        'and the actual depth, both empty and one value short', () {
      for (final entry in CalculatrixCommandRegistry.standard.entries) {
        final int? arity = entry.arity;
        if (arity == null) {
          continue;
        }
        final String valueWord = arity == 1 ? 'value' : 'values';

        try {
          Calculatrix.evaluateRpn(<String>[entry.name]);
          fail(
            'expected RpnStackUnderflowError for "${entry.name}" on an '
            'empty stack',
          );
        } on RpnStackUnderflowError catch (error) {
          expect(
            error.message,
            '${entry.name} needs $arity $valueWord on the stack, found 0.',
            reason: 'word: ${entry.name}',
          );
        }

        if (arity <= 1) {
          continue;
        }
        final List<String> oneShort = <String>[
          for (int i = 0; i < arity - 1; i++) '1',
          entry.name,
        ];
        try {
          Calculatrix.evaluateRpn(oneShort);
          fail(
            'expected RpnStackUnderflowError for "${entry.name}" one '
            'value short of its arity',
          );
        } on RpnStackUnderflowError catch (error) {
          expect(
            error.message,
            '${entry.name} needs $arity $valueWord on the stack, '
            'found ${arity - 1}.',
            reason: 'word: ${entry.name}',
          );
        }
      }
    });

    // zeros, ones, delete-row, delete-col, duplicate-row, duplicate-col,
    // move-row and move-col all pop and validate one argument (a count or
    // a 1-based index) before ever popping the next: with only one value
    // on the stack, a negative or non-integer first argument must still
    // report its own type-mismatch from main, the one case a declared
    // arity would instead mask behind a stack-underflow that names the
    // wrong problem entirely ("zeros needs 2 values, found 1" instead of
    // "zeros requires a non-negative integer count, found -1.0", issue
    // #51, AC8 regression). None of these eight words declares an arity
    // any more; this documents why, by reproducing the exact main-era
    // error id and message for each.
    test(
      'count/index-taking words without a declared arity still report '
      'their own type-mismatch, not a stack-underflow, when the stack is '
      'one value short of their real need (issue #51, AC8)',
      () {
        for (final entry in CalculatrixCommandRegistry.standard.entries) {
          if (entry.arity != null) {
            continue;
          }
          final String? message = switch (entry.name) {
            'zeros' => 'zeros requires a non-negative integer count, '
                'found -1.',
            'ones' => 'ones requires a non-negative integer count, '
                'found -1.',
            'delete-row' => 'delete-row requires a positive integer index, '
                'found -1.',
            'delete-col' => 'delete-col requires a positive integer index, '
                'found -1.',
            'duplicate-row' =>
              'duplicate-row requires a positive integer index, found -1.',
            'duplicate-col' =>
              'duplicate-col requires a positive integer index, found -1.',
            'move-row' => 'move-row requires a positive integer index, '
                'found -1.',
            'move-col' => 'move-col requires a positive integer index, '
                'found -1.',
            _ => null,
          };
          if (message == null) {
            // Some arity-less words (vector, pick, roll, rows, ...) are
            // not count/index-taking in this same way; they are covered
            // by their own dedicated tests elsewhere, not here.
            continue;
          }

          try {
            Calculatrix.evaluateRpn(<String>['-1', entry.name]);
            fail('expected a type-mismatch for "${entry.name}"');
          } on CalculatrixError catch (error) {
            expect(
              error.errorId,
              CalculatrixErrorId.typeMismatch,
              reason: 'word: ${entry.name}',
            );
            expect(error.message, message, reason: 'word: ${entry.name}');
          }
        }
      },
    );
  });
}
