import 'dart:math' as math;
import 'parser.dart';

/// Evaluates an AST tree and returns the numeric result.
class Evaluator {
  /// Evaluates the given [node] AST and returns its numeric value.
  double evaluate(AstNode node) {
    return switch (node) {
      NumberNode(:final value) => value,
      UnaryOpNode(:final operator, :final operand) =>
        _evaluateUnary(operator, operand),
      BinaryOpNode(:final left, :final operator, :final right) =>
        _evaluateBinary(left, operator, right),
    };
  }

  double _evaluateUnary(String operator, AstNode operand) {
    final value = evaluate(operand);
    return switch (operator) {
      '-' => -value,
      '√' => math.sqrt(value),
      '%' => value / 100,
      _ => throw FormatException('Unknown unary operator: "$operator"'),
    };
  }

  double _evaluateBinary(AstNode left, String operator, AstNode right) {
    final l = evaluate(left);
    final r = evaluate(right);
    return switch (operator) {
      '+' => l + r,
      '-' => l - r,
      '×' => l * r,
      '÷' => l / r,
      _ => throw FormatException('Unknown operator: "$operator"'),
    };
  }
}
