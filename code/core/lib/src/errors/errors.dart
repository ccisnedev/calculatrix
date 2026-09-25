/// Structured domain error ids (spec section 6).
///
/// Every id here is a stable, kebab-case string suitable for machine
/// consumption (for example, `{"error": {"id": ...}}` in a CLI's JSON
/// output). Not every id is wired into every error path yet; see the
/// issue report for which paths carry which id.
enum CalculatrixErrorId {
  unknownWord('unknown-word'),
  stackUnderflow('stack-underflow'),
  typeMismatch('type-mismatch'),
  dimensionMismatch('dimension-mismatch'),
  singularMatrix('singular-matrix'),
  nonFinite('non-finite'),
  logUndefined('log-undefined'),
  ambiguousPower('ambiguous-power'),
  syntaxError('syntax-error'),
  noConvergence('no-convergence'),
  unsupportedMatrixFunction('unsupported-matrix-function');

  const CalculatrixErrorId(this.id);

  /// The kebab-case id used in structured output.
  final String id;

  @override
  String toString() => id;
}

class CalculatrixError implements Exception {
  CalculatrixError(this.message, {this.errorId, this.token, this.position});

  /// Human-readable explanation of the failure.
  final String message;

  /// The structured domain error id (spec section 6), when known.
  final CalculatrixErrorId? errorId;

  /// The offending token, when the evaluator knows it.
  final String? token;

  /// The 1-based character position of [token] in the source program,
  /// when the evaluator knows it.
  final int? position;

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer('$runtimeType: $message');
    if (errorId != null) {
      buffer.write(' [${errorId!.id}]');
    }
    if (token != null) {
      buffer.write(' (token: "$token"');
      if (position != null) {
        buffer.write(', position: $position');
      }
      buffer.write(')');
    }
    return buffer.toString();
  }
}

class MatrixShapeError extends CalculatrixError {
  MatrixShapeError(super.message, {super.errorId, super.token, super.position});
}

class MatrixDomainError extends CalculatrixError {
  MatrixDomainError(super.message, {super.errorId, super.token, super.position});
}

class MatrixIndexError extends CalculatrixError {
  MatrixIndexError(super.message, {super.errorId, super.token, super.position});
}

class RpnStackError extends CalculatrixError {
  RpnStackError(super.message, {super.errorId, super.token, super.position});
}

class RpnStackUnderflowError extends RpnStackError {
  RpnStackUnderflowError(super.message, {super.errorId, super.token, super.position});
}

class RpnStackRangeError extends RpnStackError {
  RpnStackRangeError(super.message, {super.errorId, super.token, super.position});
}

class ExpressionSyntaxError extends CalculatrixError {
  ExpressionSyntaxError(super.message, {super.errorId, super.token, super.position});
}

class UnsupportedCalculatrixOperationError extends CalculatrixError {
  UnsupportedCalculatrixOperationError(super.message, {super.errorId, super.token, super.position});
}

/// An RPN word that does not name any known operator, function or literal
/// (spec section 6). RPN never falls back to the infix evaluator for an
/// unrecognized token; it raises this instead.
class UnknownWordError extends CalculatrixError {
  UnknownWordError(String token, {int? position})
    : super(
        'Unknown word: $token',
        errorId: CalculatrixErrorId.unknownWord,
        token: token,
        position: position,
      );
}
