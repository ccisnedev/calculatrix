/// Structured domain error ids (spec section 6).
///
/// Every id here is a stable, kebab-case string suitable for machine
/// consumption (for example, `{"error": {"id": ...}}` in a CLI's JSON
/// output). Not every id is wired into every error path; see the throw
/// sites in `Matrix`, `RpnEngine` and `Calculatrix` for which ones carry
/// which id.
enum CalculatrixErrorId {
  unknownWord('unknown-word'),
  stackUnderflow('stack-underflow'),
  typeMismatch('type-mismatch'),
  dimensionMismatch('dimension-mismatch'),
  singularMatrix('singular-matrix'),
  nonFinite('non-finite'),
  logUndefined('log-undefined'),
  ambiguousPower('ambiguous-power'),
  syntaxError('syntax-error');

  const CalculatrixErrorId(this.id);

  /// The kebab-case id used in structured output.
  final String id;

  @override
  String toString() => id;
}

class CalculatrixError implements Exception {
  CalculatrixError(
    this.message, {
    this.errorId,
    this.token,
    this.position,
    this.suggestions = const <String>[],
  });

  /// Human-readable explanation of the failure.
  final String message;

  /// "Did you mean" candidates (spec section 7, "Did you mean"), closest
  /// first. Empty when there is nothing close enough, or when this error
  /// has no notion of a suggestion at all. Only [UnknownWordError] sets
  /// this today, from [CalculatrixCommandRegistry.suggest].
  final List<String> suggestions;

  /// The structured domain error id (spec section 6), when known.
  final CalculatrixErrorId? errorId;

  /// The offending token, when the evaluator knows it.
  ///
  /// Mutable (not `final`) so the evaluator's per-token dispatch loop can
  /// enrich an error that was thrown deeper in the call stack (a `Matrix`
  /// or `RpnEngine` method, which has no notion of "token" or "input
  /// position") once it is caught back at the token that produced the
  /// command that threw it. See [enrichToken].
  String? token;

  /// The 1-based character position of [token] in the source program,
  /// when the evaluator knows it. Mutable for the same reason as [token].
  int? position;

  /// Fills in [token] and [position] from the token that was being
  /// dispatched when this error was caught, but only where this error does
  /// not already carry its own (a throw site closer to the actual token,
  /// such as an unrecognized RPN word, already knows better than the
  /// generic dispatch loop that is enriching every other error uniformly).
  void enrichToken(String token, int position) {
    this.token ??= token;
    this.position ??= position;
  }

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer('$runtimeType: $message');
    if (errorId != null) {
      buffer.write(' [${errorId!.id}]');
    }
    if (token != null) {
      buffer.write(' (token: "$token"');
      if (position != null) {
        buffer.write(', position: $position');
      }
      buffer.write(')');
    }
    return buffer.toString();
  }
}

class MatrixShapeError extends CalculatrixError {
  MatrixShapeError(super.message, {super.errorId, super.token, super.position});
}

class MatrixDomainError extends CalculatrixError {
  MatrixDomainError(
    super.message, {
    super.errorId,
    super.token,
    super.position,
  });
}

class MatrixIndexError extends CalculatrixError {
  MatrixIndexError(super.message, {super.errorId, super.token, super.position});
}

class RpnStackError extends CalculatrixError {
  RpnStackError(super.message, {super.errorId, super.token, super.position});
}

class RpnStackUnderflowError extends RpnStackError {
  RpnStackUnderflowError(
    super.message, {
    super.errorId,
    super.token,
    super.position,
  });
}

class RpnStackRangeError extends RpnStackError {
  RpnStackRangeError(
    super.message, {
    super.errorId,
    super.token,
    super.position,
  });
}

class ExpressionSyntaxError extends CalculatrixError {
  ExpressionSyntaxError(
    super.message, {
    super.errorId,
    super.token,
    super.position,
  });
}

class UnsupportedCalculatrixOperationError extends CalculatrixError {
  UnsupportedCalculatrixOperationError(
    super.message, {
    super.errorId,
    super.token,
    super.position,
  });
}

/// An RPN word that does not name any known operator, function or literal
/// (spec section 6). RPN never falls back to the infix evaluator for an
/// unrecognized token; it raises this instead.
class UnknownWordError extends CalculatrixError {
  UnknownWordError(String token, {int? position, List<String> suggestions = const <String>[]})
    : super(
        suggestions.isEmpty
            ? 'Unknown word: $token'
            : 'Unknown word: $token. Did you mean ${_didYouMean(suggestions)}?',
        errorId: CalculatrixErrorId.unknownWord,
        token: token,
        position: position,
        suggestions: suggestions,
      );

  /// Renders `suggestions` as a message fragment: one name alone, two
  /// joined by "or", three or more comma-separated with "or" before the
  /// last (`"append-cols"`, `"a or b"`, `"a, b or c"`).
  static String _didYouMean(List<String> suggestions) {
    if (suggestions.length == 1) return '"${suggestions.single}"';
    final String last = suggestions.last;
    final String head = suggestions
        .take(suggestions.length - 1)
        .map((String s) => '"$s"')
        .join(', ');
    return '$head or "$last"';
  }
}

/// MR/MRC in rpn mode with nothing stored in memory. Raised only after any
/// pending draft has already been committed (the action-key commit-first
/// rule), so it always reports the true, post-commit memory state rather
/// than racing an uncommitted line. See CalculatrixSession.memoryRecall.
class EmptyMemoryError extends CalculatrixError {
  EmptyMemoryError(super.message);
}
