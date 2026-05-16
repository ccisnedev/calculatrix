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

class RpnStackUnderflowError extends CalculatrixError {
  RpnStackUnderflowError(super.message);
}

class ExpressionSyntaxError extends CalculatrixError {
  ExpressionSyntaxError(super.message);
}

class UnsupportedCalculatrixOperationError extends CalculatrixError {
  UnsupportedCalculatrixOperationError(super.message);
}
