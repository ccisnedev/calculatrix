import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('CalculatrixErrorId', () {
    test('has the ten kebab-case ids the spec requires', () {
      expect(CalculatrixErrorId.unknownWord.id, 'unknown-word');
      expect(CalculatrixErrorId.stackUnderflow.id, 'stack-underflow');
      expect(CalculatrixErrorId.typeMismatch.id, 'type-mismatch');
      expect(CalculatrixErrorId.dimensionMismatch.id, 'dimension-mismatch');
      expect(CalculatrixErrorId.singularMatrix.id, 'singular-matrix');
      expect(CalculatrixErrorId.nonFinite.id, 'non-finite');
      expect(CalculatrixErrorId.logUndefined.id, 'log-undefined');
      expect(CalculatrixErrorId.ambiguousPower.id, 'ambiguous-power');
      expect(CalculatrixErrorId.syntaxError.id, 'syntax-error');
      expect(CalculatrixErrorId.limitExceeded.id, 'limit-exceeded');
      expect(CalculatrixErrorId.values, hasLength(10));
    });
  });

  group('CalculatrixError', () {
    test('carries an optional errorId, token and position', () {
      final CalculatrixError error = CalculatrixError(
        'boom',
        errorId: CalculatrixErrorId.nonFinite,
        token: '1e999',
        position: 3,
      );

      expect(error.message, 'boom');
      expect(error.errorId, CalculatrixErrorId.nonFinite);
      expect(error.token, '1e999');
      expect(error.position, 3);
    });

    test('defaults errorId, token and position to null', () {
      final CalculatrixError error = CalculatrixError('boom');

      expect(error.errorId, isNull);
      expect(error.token, isNull);
      expect(error.position, isNull);
    });

    test('toString includes the errorId and token when present', () {
      final CalculatrixError error = CalculatrixError(
        'boom',
        errorId: CalculatrixErrorId.nonFinite,
        token: '1e999',
        position: 3,
      );

      expect(error.toString(), contains('boom'));
      expect(error.toString(), contains('[non-finite]'));
      expect(error.toString(), contains('token: "1e999"'));
      expect(error.toString(), contains('position: 3'));
    });

    test('every subclass forwards errorId/token/position', () {
      const CalculatrixErrorId id = CalculatrixErrorId.dimensionMismatch;
      expect(
        MatrixShapeError('m', errorId: id, token: 't', position: 1).errorId,
        id,
      );
      expect(
        MatrixDomainError('m', errorId: id, token: 't', position: 1).errorId,
        id,
      );
      expect(
        MatrixIndexError('m', errorId: id, token: 't', position: 1).errorId,
        id,
      );
      expect(
        RpnStackError('m', errorId: id, token: 't', position: 1).errorId,
        id,
      );
      expect(
        RpnStackUnderflowError(
          'm',
          errorId: id,
          token: 't',
          position: 1,
        ).errorId,
        id,
      );
      expect(
        RpnStackRangeError('m', errorId: id, token: 't', position: 1).errorId,
        id,
      );
      expect(
        ExpressionSyntaxError(
          'm',
          errorId: id,
          token: 't',
          position: 1,
        ).errorId,
        id,
      );
      expect(
        UnsupportedCalculatrixOperationError(
          'm',
          errorId: id,
          token: 't',
          position: 1,
        ).errorId,
        id,
      );
    });
  });

  group('UnknownWordError', () {
    test('carries the unknown-word id, the token and its position', () {
      final UnknownWordError error = UnknownWordError(
        'frobnicate',
        position: 5,
      );

      expect(error.errorId, CalculatrixErrorId.unknownWord);
      expect(error.token, 'frobnicate');
      expect(error.position, 5);
      expect(error.message, contains('frobnicate'));
    });

    test('position is optional', () {
      final UnknownWordError error = UnknownWordError('frobnicate');
      expect(error.position, isNull);
    });
  });
}
