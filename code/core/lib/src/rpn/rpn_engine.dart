import '../errors/errors.dart';
import '../matrix/matrix.dart';

enum RpnBinaryOperator { add, subtract, multiply, divide }

enum RpnUnaryOperator { sqrt, percent }

class RpnEngine {
  final List<Matrix> _stack = <Matrix>[];

  int get depth => _stack.length;

  List<Matrix> get stack {
    return List<Matrix>.unmodifiable(_stack);
  }

  void clear() {
    _stack.clear();
  }

  // Restores the stack to a previously captured snapshot (see `stack`).
  // Used by CalculatrixMachine.execute to roll back a command that threw
  // partway through, so a failing command never leaves the stack with
  // some operands popped and others not.
  void restore(List<Matrix> snapshot) {
    _stack
      ..clear()
      ..addAll(snapshot);
  }

  void push(Matrix value) {
    _stack.add(value);
  }

  void pushScalar(double value) {
    push(Matrix.scalar(value));
  }

  // pick, roll and drop are the only stack-shuffling primitives the engine
  // itself implements. dup, swap, over and rot are not engine methods:
  // they are pure RPN definitions (1 pick, 2 roll, 2 pick, 3 roll) that
  // compile down to these same primitives, so there is exactly one
  // implementation of "read/move the nth value from the top" (D44) and a
  // defined word never duplicates engine logic of its own (issue #39).
  Matrix drop() {
    if (_stack.isEmpty) {
      throw RpnStackUnderflowError(
        'Cannot drop from an empty RPN stack.',
        errorId: CalculatrixErrorId.stackUnderflow,
        needed: 1,
        found: 0,
      );
    }

    return _stack.removeLast();
  }

  Matrix pick(int indexFromTop) {
    _requireValidRange(indexFromTop);

    final Matrix value = _stack[_stack.length - indexFromTop];
    _stack.add(value);
    return value;
  }

  Matrix roll(int indexFromTop) {
    _requireValidRange(indexFromTop);

    final int sourceIndex = _stack.length - indexFromTop;
    final Matrix value = _stack.removeAt(sourceIndex);
    _stack.add(value);
    return value;
  }

  Matrix peek() {
    if (_stack.isEmpty) {
      throw RpnStackUnderflowError(
        'Cannot peek from an empty RPN stack.',
        errorId: CalculatrixErrorId.stackUnderflow,
        needed: 1,
        found: 0,
      );
    }

    return _stack.last;
  }

  Matrix pop() {
    if (_stack.isEmpty) {
      throw RpnStackUnderflowError(
        'Cannot pop from an empty RPN stack.',
        errorId: CalculatrixErrorId.stackUnderflow,
        needed: 1,
        found: 0,
      );
    }

    return _stack.removeLast();
  }

  Matrix applyBinary(RpnBinaryOperator operatorType) {
    if (_stack.length < 2) {
      throw RpnStackUnderflowError(
        'A binary operation requires at least two values.',
        errorId: CalculatrixErrorId.stackUnderflow,
        needed: 2,
        found: _stack.length,
      );
    }

    // Read the operands without removing them yet: if the computation below
    // throws, the stack is left exactly as it was. Only the failing
    // operation is rolled back, not the operands that were already there.
    final Matrix right = _stack[_stack.length - 1];
    final Matrix left = _stack[_stack.length - 2];

    late final Matrix result;
    switch (operatorType) {
      case RpnBinaryOperator.add:
        result = left + right;
      case RpnBinaryOperator.subtract:
        result = left - right;
      case RpnBinaryOperator.multiply:
        result = left * right;
      case RpnBinaryOperator.divide:
        result = _divide(left, right);
    }

    _stack.removeLast();
    _stack.removeLast();
    _stack.add(result);
    return result;
  }

  Matrix applyUnary(RpnUnaryOperator operatorType) {
    if (_stack.isEmpty) {
      throw RpnStackUnderflowError(
        'A unary operation requires at least one value.',
        errorId: CalculatrixErrorId.stackUnderflow,
        needed: 1,
        found: 0,
      );
    }

    // Same rationale as applyBinary: compute first, mutate the stack only
    // once the computation has succeeded.
    final Matrix value = _stack.last;

    late final Matrix result;
    switch (operatorType) {
      case RpnUnaryOperator.sqrt:
        result = _sqrt(value);
      case RpnUnaryOperator.percent:
        result = _percent(value);
    }

    _stack.removeLast();

    _stack.add(result);
    return result;
  }

  Matrix _divide(Matrix left, Matrix right) {
    return left / right;
  }

  Matrix _sqrt(Matrix value) {
    return value.sqrt();
  }

  Matrix _percent(Matrix value) {
    return value.scale(0.01);
  }

  // A malformed index (less than 1) is a range error: it can never be valid,
  // regardless of how deep the stack is. An index that is well-formed but
  // reaches past the current depth (including the empty-stack case, where
  // every index from 1 up is out of reach) is a stack-underflow: there
  // simply are not enough values yet, the same condition drop reports
  // (AC4, issue #39).
  void _requireValidRange(int indexFromTop) {
    if (indexFromTop < 1) {
      throw RpnStackRangeError(
        'Stack index must be 1-based and greater than zero.',
      );
    }

    if (indexFromTop > _stack.length) {
      throw RpnStackUnderflowError(
        'Stack index $indexFromTop exceeds current depth ${_stack.length}.',
        errorId: CalculatrixErrorId.stackUnderflow,
        needed: indexFromTop,
        found: _stack.length,
      );
    }
  }
}
