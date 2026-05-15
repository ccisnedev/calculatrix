/// The type of a token in a mathematical expression.
enum TokenType {
  /// A numeric literal (integer or decimal).
  number,

  /// Addition operator (+).
  plus,

  /// Subtraction operator (-).
  minus,

  /// Multiplication operator (×).
  multiply,

  /// Division operator (÷).
  divide,

  /// Opening parenthesis.
  leftParen,

  /// Closing parenthesis.
  rightParen,

  /// Square root function (√).
  sqrt,

  /// Percent operator (%).
  percent,
}

/// A single token extracted from an input expression string.
class Token {
  /// Creates a token with the given [type] and [value].
  const Token(this.type, this.value);

  /// The classification of this token.
  final TokenType type;

  /// The raw string value of this token.
  final String value;

  /// Whether this token is a binary operator.
  bool get isOperator =>
      type == TokenType.plus ||
      type == TokenType.minus ||
      type == TokenType.multiply ||
      type == TokenType.divide;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Token && other.type == type && other.value == value;

  @override
  int get hashCode => Object.hash(type, value);

  @override
  String toString() => 'Token($type, "$value")';
}
