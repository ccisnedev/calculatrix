import '../errors/errors.dart';
import '../exact/rational.dart';
import '../matrix/matrix.dart';
import '../names/name_table.dart';

/// Numeric and matrix literals, shared by RPN and infix.
///
/// A literal is exact (runbook D50): `0.1` is 1/10 and `1e400` is 10^400.
/// A `~` in front of a literal, its sign included, makes it approximate
/// (runbook D56): `~0.1`, `~-0.1`, `~[[1 2]]`. A `~` on one entry of a
/// matrix literal makes the whole matrix approximate (runbook D49). A
/// fraction of two integers, `1/3` or `-5/3`, is a literal too (runbook
/// D59), so every exact value `cx` prints can be typed back, alone or as a
/// matrix entry.
abstract final class Literals {
  /// The approximate mark of runbook D54 and D56.
  static const String approximateMark = '~';

  static final RegExp _number = RegExp(
    r'^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$',
  );

  static final RegExp _fraction = RegExp(r'^([+-]?\d+)/(\d+)$');

  /// Whether [text] is a numeric literal (exact or with `~`), a fraction
  /// included, and `NaN` or `Infinity` too: they are literals that always
  /// fail as `non-finite`.
  static bool isNumber(String text) {
    final String unmarked = _unmark(text);
    return _number.hasMatch(unmarked) ||
        _fraction.hasMatch(unmarked) ||
        _isNonFiniteWord(unmarked);
  }

  /// Whether [text] has the shape of a matrix literal: brackets, with an
  /// optional `~` and sign in front.
  static bool looksLikeMatrix(String text) {
    final String unsigned = _stripSign(_unmark(text));
    return unsigned.startsWith('[') && unsigned.endsWith(']');
  }

  /// Whether [text] is a literal of either kind.
  static bool isLiteral(String text) => looksLikeMatrix(text) || isNumber(text);

  /// The text with the `~` placed before the sign, when [text] is a sign
  /// followed by a marked literal (`-~0.1` gives `~-0.1`), or null. The mark
  /// belongs to the literal, so that form is a syntax error (runbook D56).
  static String? misplacedMarkFix(String text) {
    if (text.length < 3 ||
        (text[0] != '-' && text[0] != '+') ||
        text[1] != approximateMark) {
      return null;
    }
    final String fixed = '$approximateMark${text[0]}${text.substring(2)}';
    final String rest = text.substring(2);
    if (rest.startsWith('-') || rest.startsWith('+')) {
      return null;
    }
    return isLiteral(fixed) ? fixed : null;
  }

  /// The value [text] spells, or null when it is not a literal.
  ///
  /// Throws `limit-exceeded` when an exact number would have more than
  /// [maxDigits] digits (runbook D55), `non-finite` for `NaN`, `Infinity`
  /// and an approximate number out of the `double` range, and
  /// `syntax-error` for a misplaced `~` or a malformed matrix literal.
  static Matrix? parse(String text, {required int maxDigits}) {
    final String? fix = misplacedMarkFix(text);
    if (fix != null) {
      throw ExpressionSyntaxError(
        'The approximate mark goes before the sign: $fix',
        errorId: CalculatrixErrorId.syntaxError,
        token: text,
      );
    }
    if (looksLikeMatrix(text)) {
      return _parseMatrix(text, maxDigits);
    }
    if (!isNumber(text)) {
      return null;
    }
    final _Entry entry = _parseNumber(text, text, maxDigits);
    return entry.exact != null
        ? Matrix.exactScalar(entry.exact!)
        : Matrix.scalar(entry.approximate!);
  }

  static String _unmark(String text) => text.startsWith(approximateMark)
      ? text.substring(approximateMark.length)
      : text;

  static String _stripSign(String text) =>
      text.startsWith('-') || text.startsWith('+') ? text.substring(1) : text;

  static bool _isNonFiniteWord(String text) {
    final String unsigned = _stripSign(text);
    return unsigned == 'NaN' || unsigned == 'Infinity';
  }

  // One numeric entry, exact or approximate. [token] is the whole literal
  // it belongs to, for the messages.
  // With [approximate], the entry belongs to a marked matrix and is read
  // as approximate even without its own mark.
  static _Entry _parseNumber(
    String text,
    String token,
    int maxDigits, {
    bool approximate = false,
  }) {
    final bool marked = approximate || text.startsWith(approximateMark);
    final String unmarked = _unmark(text);
    if (_isNonFiniteWord(unmarked)) {
      throw MatrixDomainError(
        'Numeric literal is not a finite number: $token',
        errorId: CalculatrixErrorId.nonFinite,
        token: token,
      );
    }
    final RegExpMatch? fraction = _fraction.firstMatch(unmarked);
    if (fraction != null) {
      return _parseFraction(fraction, token, maxDigits, marked: marked);
    }
    if (marked) {
      final double value = double.parse(unmarked);
      if (!value.isFinite) {
        throw MatrixDomainError(
          'Numeric literal is not a finite number: $token',
          errorId: CalculatrixErrorId.nonFinite,
          token: token,
        );
      }
      return _Entry.approximate(value);
    }
    final Rational? value = Rational.tryParseDecimal(
      unmarked,
      maxDigits: maxDigits,
      onTooLarge: (int estimated) => LimitExceededError(
        'The literal $unmarked has about $estimated digits, over the limit '
        'of $maxDigits.',
        limit: maxDigits,
        estimated: estimated,
        token: token,
      ),
    );
    return _Entry.exact(value!);
  }

  // A fraction `p/q` of two integers (runbook D59): exact, or the double
  // nearest to it when [marked], with no digit limit then, as for a marked
  // decimal. A zero denominator is `non-finite`, as the division `p q /`
  // is.
  static _Entry _parseFraction(
    RegExpMatch fraction,
    String token,
    int maxDigits, {
    required bool marked,
  }) {
    Rational part(String text) => Rational.tryParseDecimal(
      text,
      maxDigits: marked ? Rational.maxEstimate : maxDigits,
      onTooLarge: (int estimated) => LimitExceededError(
        'The literal ${fraction.group(0)} has about $estimated digits, over '
        'the limit of $maxDigits.',
        limit: maxDigits,
        estimated: estimated,
        token: token,
      ),
    )!;
    final Rational numerator = part(fraction.group(1)!);
    final Rational denominator = part(fraction.group(2)!);
    if (denominator.isZero) {
      throw MatrixDomainError(
        'The literal ${fraction.group(0)} divides by zero: $token',
        errorId: CalculatrixErrorId.nonFinite,
        token: token,
      );
    }
    final Rational value = numerator / denominator;
    if (!marked) {
      return _Entry.exact(value);
    }
    final double approximate = value.toDouble();
    if (!approximate.isFinite) {
      throw MatrixDomainError(
        'Numeric literal is not a finite number: $token',
        errorId: CalculatrixErrorId.nonFinite,
        token: token,
      );
    }
    return _Entry.approximate(approximate);
  }

  static Matrix _parseMatrix(String token, int maxDigits) {
    final bool outerMark = token.startsWith(approximateMark);
    String body = _unmark(token);
    final bool negative = body.startsWith('-');
    body = _stripSign(body);

    final Object tree = _MatrixLiteralParser(body, token).parse();
    final List<List<String>> rows = _shape(tree as List<Object>, token);

    // One `~`, outside or on any entry, makes the whole matrix approximate
    // (runbook D56), so no entry is read as exact first.
    final bool marked =
        outerMark ||
        rows.any(
          (List<String> row) =>
              row.any((String text) => text.startsWith(approximateMark)),
        );
    final List<List<_Entry>> entries = <List<_Entry>>[
      for (final List<String> row in rows)
        <_Entry>[
          for (final String text in row)
            _parseNumber(text, token, maxDigits, approximate: marked),
        ],
    ];

    final Matrix matrix;
    if (marked) {
      matrix = Matrix(<List<double>>[
        for (final List<_Entry> row in entries)
          <double>[for (final _Entry entry in row) entry.toDouble(token)],
      ]);
    } else {
      matrix = Matrix.exact(<List<Rational>>[
        for (final List<_Entry> row in entries)
          <Rational>[for (final _Entry entry in row) entry.exact!],
      ]);
    }
    if (!negative) {
      return matrix;
    }
    return marked
        ? matrix.scale(-1)
        : Matrix.exact(<List<Rational>>[
            for (final List<Rational> row in matrix.exactRows)
              <Rational>[for (final Rational entry in row) -entry],
          ]);
  }

  // A flat list of numbers is one row (`[1 2 3]`); a list of lists is a
  // matrix, one list per row (`[[1 2] [3 4]]`).
  static List<List<String>> _shape(List<Object> tree, String token) {
    if (tree.isEmpty) {
      // An empty matrix literal is well-formed syntax that names an
      // impossible shape, in both RPN and infix, so this is
      // dimension-mismatch, not syntax-error (spec section 6).
      throw MatrixShapeError(
        'Matrix literal cannot be empty.',
        errorId: CalculatrixErrorId.dimensionMismatch,
      );
    }
    if (tree.every((Object item) => item is String)) {
      return <List<String>>[tree.cast<String>()];
    }
    final List<List<String>> rows = <List<String>>[];
    for (final Object row in tree) {
      if (row is! List<Object> || row.isEmpty) {
        throw ExpressionSyntaxError(
          'Invalid matrix row in literal: $token',
          errorId: CalculatrixErrorId.syntaxError,
        );
      }
      if (row.any((Object item) => item is! String)) {
        throw ExpressionSyntaxError(
          'Matrix literal must contain only numbers.',
          errorId: CalculatrixErrorId.syntaxError,
        );
      }
      rows.add(row.cast<String>());
    }
    return rows;
  }
}

final class _Entry {
  _Entry.exact(Rational this.exact) : approximate = null;
  _Entry.approximate(double this.approximate) : exact = null;

  final Rational? exact;
  final double? approximate;

  // An exact entry in a matrix made approximate by a `~` elsewhere.
  double toDouble(String token) {
    final double value = approximate ?? exact!.toDouble();
    if (!value.isFinite) {
      throw MatrixDomainError(
        'Matrix literal contains a non-finite value: $token',
        errorId: CalculatrixErrorId.nonFinite,
      );
    }
    return value;
  }
}

// Parses the bracket structure of a matrix literal into nested lists of
// entry texts. Entries are separated by commas, whitespace or both, and
// rows may touch with no separator at all, as in the HP 50g's own
// `[[0 -1][1 0]]` (issue #29).
final class _MatrixLiteralParser {
  _MatrixLiteralParser(this._source, this._token);

  final String _source;
  final String _token;
  int _index = 0;

  Object parse() {
    final Object value = _list(1);
    _skipSpace();
    if (_index != _source.length) {
      throw _invalid();
    }
    return value;
  }

  // A matrix literal nests two levels at most (`[[1 2] [3 4]]`); deeper
  // nesting stops here, before any recursion that could exhaust the stack.
  List<Object> _list(int depth) {
    if (depth > 2) {
      throw ExpressionSyntaxError(
        'Matrix literal must contain only numbers.',
        errorId: CalculatrixErrorId.syntaxError,
      );
    }
    _expect('[');
    final List<Object> items = <Object>[];
    _skipSpace();
    if (_peek == ']') {
      _index++;
      return items;
    }
    while (true) {
      items.add(_peek == '[' ? _list(depth + 1) : _entry());
      final bool spaced = _skipSpace();
      final String? next = _peek;
      if (next == ']') {
        _index++;
        return items;
      }
      if (next == ',') {
        _index++;
        _skipSpace();
        if (_peek == ']' || _peek == ',' || _peek == null) {
          throw _invalid();
        }
        continue;
      }
      final bool rowsTouch = next == '[' && items.last is List<Object>;
      if (next == null || !(spaced || rowsTouch)) {
        throw _invalid();
      }
    }
  }

  String _entry() {
    final int start = _index;
    while (_index < _source.length && !_isDelimiter(_source[_index])) {
      _index++;
    }
    final String text = _source.substring(start, _index);
    final String? fix = Literals.misplacedMarkFix(text);
    if (fix != null) {
      throw ExpressionSyntaxError(
        'The approximate mark goes before the sign: $fix',
        errorId: CalculatrixErrorId.syntaxError,
        token: _token,
      );
    }
    if (text.isEmpty || !Literals.isNumber(text)) {
      throw _invalid();
    }
    return text;
  }

  bool _skipSpace() {
    final int start = _index;
    while (_index < _source.length && _source[_index].trim().isEmpty) {
      _index++;
    }
    return _index > start;
  }

  String? get _peek => _index < _source.length ? _source[_index] : null;

  void _expect(String character) {
    if (_peek != character) {
      throw _invalid();
    }
    _index++;
  }

  static bool _isDelimiter(String character) =>
      character == '[' ||
      character == ']' ||
      character == ',' ||
      character.trim().isEmpty;

  // A name of the name table inside the literal (`[[pi 0] [0 1]]`) is the
  // one cause of an invalid literal the message can name: entries must be
  // numbers, and a constant is a name (runbook-agent-usability.md D67). A
  // letter right after a digit or a dot is part of a number (`1e3`), not a
  // name.
  static final RegExp _nameInLiteral = RegExp(
    r'(?<![0-9A-Za-z_.])[A-Za-zπ_][A-Za-z0-9_π]*',
  );

  ExpressionSyntaxError _invalid() {
    String? constant;
    for (final RegExpMatch match in _nameInLiteral.allMatches(_token)) {
      if (CalculatrixNameTable.standard.lookup(match.group(0)!) != null) {
        constant = match.group(0);
        break;
      }
    }
    return ExpressionSyntaxError(
      constant == null
          ? 'Invalid matrix literal: $_token'
          : 'Invalid matrix literal: $_token; entries must be numbers, '
                '"$constant" is a constant',
      errorId: CalculatrixErrorId.syntaxError,
    );
  }
}
