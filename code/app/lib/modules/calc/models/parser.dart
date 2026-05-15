import 'token.dart';

/// AST node base class.
sealed class AstNode {}

/// A numeric literal node.
class NumberNode extends AstNode {
  NumberNode(this.value);
  final double value;
}

/// A binary operation node (left op right).
class BinaryOpNode extends AstNode {
  BinaryOpNode(this.left, this.operator, this.right);
  final AstNode left;
  final String operator;
  final AstNode right;
}

/// A unary operation node (op operand).
class UnaryOpNode extends AstNode {
  UnaryOpNode(this.operator, this.operand);
  final String operator;
  final AstNode operand;
}

/// Recursive descent parser with PEMDAS precedence.
///
/// Grammar:
///   expression = term (('+' | '-') term)*
///   term       = unary (('×' | '÷') unary)*
///   unary      = '-' unary | '√' unary | primary
///   primary    = NUMBER '%'? | '(' expression ')' '%'?
class Parser {
  List<Token> _tokens = [];
  int _pos = 0;

  /// Parses a list of tokens into an AST.
  AstNode parse(List<Token> tokens) {
    if (tokens.isEmpty) {
      throw const FormatException('Empty expression');
    }
    _tokens = tokens;
    _pos = 0;
    final result = _expression();
    if (_pos < _tokens.length) {
      throw FormatException(
        'Unexpected token: "${_tokens[_pos].value}" at position $_pos',
      );
    }
    return result;
  }

  Token? get _current => _pos < _tokens.length ? _tokens[_pos] : null;

  Token _advance() => _tokens[_pos++];

  bool _match(TokenType type) {
    if (_current?.type == type) {
      _advance();
      return true;
    }
    return false;
  }

  /// expression = term (('+' | '-') term)*
  AstNode _expression() {
    var left = _term();
    while (_current != null &&
        (_current!.type == TokenType.plus || _current!.type == TokenType.minus)) {
      final op = _advance().value;
      final right = _term();
      left = BinaryOpNode(left, op, right);
    }
    return left;
  }

  /// term = unary (('×' | '÷') unary)*
  AstNode _term() {
    var left = _unary();
    while (_current != null &&
        (_current!.type == TokenType.multiply ||
            _current!.type == TokenType.divide)) {
      final op = _advance().value;
      final right = _unary();
      left = BinaryOpNode(left, op, right);
    }
    return left;
  }

  /// unary = '-' unary | '√' unary | primary
  AstNode _unary() {
    if (_current?.type == TokenType.minus) {
      _advance();
      final operand = _unary();
      return UnaryOpNode('-', operand);
    }
    if (_current?.type == TokenType.sqrt) {
      _advance();
      final operand = _unary();
      return UnaryOpNode('√', operand);
    }
    return _primary();
  }

  /// primary = NUMBER '%'? | '(' expression ')' '%'?
  AstNode _primary() {
    if (_current == null) {
      throw const FormatException('Unexpected end of expression');
    }

    if (_current!.type == TokenType.number) {
      final token = _advance();
      AstNode node = NumberNode(double.parse(token.value));
      if (_current?.type == TokenType.percent) {
        _advance();
        node = UnaryOpNode('%', node);
      }
      return node;
    }

    if (_match(TokenType.leftParen)) {
      final expr = _expression();
      if (!_match(TokenType.rightParen)) {
        throw const FormatException('Missing closing parenthesis');
      }
      AstNode node = expr;
      if (_current?.type == TokenType.percent) {
        _advance();
        node = UnaryOpNode('%', node);
      }
      return node;
    }

    throw FormatException('Unexpected token: "${_current!.value}"');
  }
}
