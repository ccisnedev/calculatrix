import '../matrix/matrix.dart';

enum RpnBinaryOperator { add, subtract, multiply }

class RpnEngine {
  final List<Matrix> _stack = <Matrix>[];

  int get depth => _stack.length;

  List<Matrix> get stack {
    return List<Matrix>.unmodifiable(_stack);
  }

  void clear() {
    _stack.clear();
  }

  void push(Matrix value) {
    _stack.add(value);
  }

  void pushScalar(double value) {
    push(Matrix.scalar(value));
  }

  Matrix peek() {
    if (_stack.isEmpty) {
      throw StateError('Cannot peek from an empty RPN stack.');
    }

    return _stack.last;
  }

  Matrix pop() {
    if (_stack.isEmpty) {
      throw StateError('Cannot pop from an empty RPN stack.');
    }

    return _stack.removeLast();
  }

  Matrix applyBinary(RpnBinaryOperator operatorType) {
    if (_stack.length < 2) {
      throw StateError('A binary operation requires at least two values.');
    }

    final Matrix right = _stack.removeLast();
    final Matrix left = _stack.removeLast();

    late final Matrix result;
    switch (operatorType) {
      case RpnBinaryOperator.add:
        result = left + right;
      case RpnBinaryOperator.subtract:
        result = left - right;
      case RpnBinaryOperator.multiply:
        result = left * right;
    }

    _stack.add(result);
    return result;
  }
}
