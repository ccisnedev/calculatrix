import '../errors/errors.dart';
import '../exact/exact_arithmetic.dart';
import '../exact/exact_roots.dart';
import '../exact/rational.dart';
import '../matrix/matrix.dart';

enum RpnBinaryOperator { add, subtract, multiply, divide }

enum RpnUnaryOperator { sqrt, percent }

/// The RPN stack (runbook D49): every value on it is either exact or
/// approximate, as a whole.
///
/// [pop] and [peek] hand out approximate values, so a command written for
/// `double` matrices sees approximate operands whatever the stack holds and
/// its result is approximate (runbook D53: until a word becomes exact, it
/// converts its exact operands, marked, never silently). A command that
/// keeps exactness reads its operands with [popAny] instead.
class RpnEngine {
  RpnEngine({this.exact = const ExactArithmetic()});

  /// The exact operations, with the digit limit of runbook D55.
  final ExactArithmetic exact;

  final List<Matrix> _stack = <Matrix>[];

  int get depth => _stack.length;

  /// The values as they are, exact or approximate, bottom to top.
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
  // They move values as they are, so exactness is kept (runbook D53).
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

  /// The top value, approximate (see the class comment).
  Matrix peek() {
    if (_stack.isEmpty) {
      throw RpnStackUnderflowError(
        'Cannot peek from an empty RPN stack.',
        errorId: CalculatrixErrorId.stackUnderflow,
        needed: 1,
        found: 0,
      );
    }

    return _stack.last.toApproximate();
  }

  /// Removes the top value and returns it approximate (see the class
  /// comment).
  Matrix pop() => popAny().toApproximate();

  /// Removes the top value and returns it as it is, exact or approximate.
  Matrix popAny() {
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

  /// Exact when both operands are exact, approximate otherwise (runbook
  /// D51).
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
    if (left.isExact && right.isExact) {
      switch (operatorType) {
        case RpnBinaryOperator.add:
          result = exact.add(left, right);
        case RpnBinaryOperator.subtract:
          result = exact.subtract(left, right);
        case RpnBinaryOperator.multiply:
          result = exact.multiply(left, right);
        case RpnBinaryOperator.divide:
          result = exact.divide(left, right);
      }
    } else {
      final Matrix a = left.toApproximate();
      final Matrix b = right.toApproximate();
      switch (operatorType) {
        case RpnBinaryOperator.add:
          result = a + b;
        case RpnBinaryOperator.subtract:
          result = a - b;
        case RpnBinaryOperator.multiply:
          result = a * b;
        case RpnBinaryOperator.divide:
          result = a / b;
      }
    }

    _stack.removeLast();
    _stack.removeLast();
    _stack.add(result);
    return result;
  }

  /// Both keep exactness: `sqrt` is exact when the root is rational, as
  /// `0.5 power` is (runbook D53).
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
        result = value.isExact
            ? exact.fractionalPower(value, Rational(BigInt.one, BigInt.two))
            : value.sqrt();
      case RpnUnaryOperator.percent:
        result = value.isExact ? exact.percent(value) : value.scale(0.01);
    }

    _stack.removeLast();

    _stack.add(result);
    return result;
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
