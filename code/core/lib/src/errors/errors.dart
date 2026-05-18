class CalculatrixError implements Exception {
  CalculatrixError(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class MatrixShapeError extends CalculatrixError {
  MatrixShapeError(super.message);
}

class MatrixDomainError extends CalculatrixError {
  MatrixDomainError(super.message);
}

class MatrixIndexError extends CalculatrixError {
  MatrixIndexError(super.message);
}

class RpnStackError extends CalculatrixError {
  RpnStackError(super.message);
}

class RpnStackUnderflowError extends RpnStackError {
  RpnStackUnderflowError(super.message);
}

class RpnStackRangeError extends RpnStackError {
  RpnStackRangeError(super.message);
}

class ExpressionSyntaxError extends CalculatrixError {
  ExpressionSyntaxError(super.message);
}

class UnsupportedCalculatrixOperationError extends CalculatrixError {
  UnsupportedCalculatrixOperationError(super.message);
}
