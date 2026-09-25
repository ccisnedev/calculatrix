import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('CalculatrixErrorId', () {
    test('defines the nine domain error ids from the spec', () {
      final Set<String> ids = CalculatrixErrorId.values
          .map((CalculatrixErrorId id) => id.id)
          .toSet();

      expect(ids, <String>{
        'unknown-word',
        'stack-underflow',
        'type-mismatch',
        'dimension-mismatch',
        'singular-matrix',
        'non-finite',
        'log-undefined',
        'ambiguous-power',
        'syntax-error',
      });
    });
  });

  group('CalculatrixError', () {
    test('carries an optional errorId, token and position', () {
      final MatrixDomainError error = MatrixDomainError(
        'boom',
        errorId: CalculatrixErrorId.nonFinite,
        token: '1e999',
        position: 3,
      );

      expect(error.errorId, CalculatrixErrorId.nonFinite);
      expect(error.token, '1e999');
      expect(error.position, 3);
      expect(error.message, 'boom');
    });

    test('errorId, token and position default to null', () {
      final MatrixDomainError error = MatrixDomainError('boom');

      expect(error.errorId, isNull);
      expect(error.token, isNull);
      expect(error.position, isNull);
    });
  });

  group('UnknownWordError', () {
    test('carries the unknown-word id and the offending token', () {
      final UnknownWordError error = UnknownWordError('banana');

      expect(error.errorId, CalculatrixErrorId.unknownWord);
      expect(error.token, 'banana');
      expect(error, isA<CalculatrixError>());
    });
  });
}
