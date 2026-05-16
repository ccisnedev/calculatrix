import '../errors/errors.dart';
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

  Matrix dup() {
    if (_stack.isEmpty) {
      throw RpnStackUnderflowError('Cannot dup from an empty RPN stack.');
    }

    final Matrix top = _stack.last;
    _stack.add(top);
    return top;
  }

  Matrix drop() {
    if (_stack.isEmpty) {
      throw RpnStackUnderflowError('Cannot drop from an empty RPN stack.');
    }

    return _stack.removeLast();
  }

  void swap() {
    if (_stack.length < 2) {
      throw RpnStackUnderflowError(
        'Swap requires at least two values in the stack.',
      );
    }

    final int top = _stack.length - 1;
    final Matrix a = _stack[top];
    _stack[top] = _stack[top - 1];
    _stack[top - 1] = a;
  }

  Matrix over() {
    if (_stack.length < 2) {
      throw RpnStackUnderflowError(
        'Over requires at least two values in the stack.',
      );
    }

    final Matrix second = _stack[_stack.length - 2];
    _stack.add(second);
    return second;
  }

  Matrix peek() {
    if (_stack.isEmpty) {
      throw RpnStackUnderflowError('Cannot peek from an empty RPN stack.');
    }

    return _stack.last;
  }

  Matrix pop() {
    if (_stack.isEmpty) {
      throw RpnStackUnderflowError('Cannot pop from an empty RPN stack.');
    }

    return _stack.removeLast();
  }

  Matrix applyBinary(RpnBinaryOperator operatorType) {
    if (_stack.length < 2) {
      throw RpnStackUnderflowError(
        'A binary operation requires at least two values.',
      );
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
