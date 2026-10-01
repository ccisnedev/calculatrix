/// Every top-level word `buildCalculatrixCli` registers a real route under
/// (the `eval`/`commands` modules, and the `version`/`doctor`/`upgrade`/
/// `uninstall`/`help` plugin commands). An invocation whose first argument
/// is none of these, and is not an option, never reaches a named command at
/// all: it only ever matches the bare `<program>` shortcut (spec section 4,
/// G4), so more than one such argument can only mean the program itself was
/// typed unquoted, one RPN word per shell argument, instead of as the one
/// quoted string the shortcut's contract requires.
const Set<String> reservedTopLevelWords = <String>{
  'eval',
  'commands',
  'version',
  'doctor',
  'upgrade',
  'uninstall',
  'help',
};

/// Whether [args] looks like an RPN program typed as separate shell words
/// (`cx 5 7 power`) rather than one quoted string (`cx '5 7 power'`):
/// more than one argument, the first of which neither names a registered
/// command nor is an option.
///
/// This alone does not mean the invocation failed; `cx 5` is a single
/// argument and never matches this at all, and this is only ever consulted
/// once `modular_cli_sdk` has already rejected the invocation with
/// `extra-argument` (see [rewriteUnquotedProgramError]).
bool looksLikeUnquotedProgram(List<String> args) {
  if (args.length < 2) return false;
  final String first = args.first;
  if (first.startsWith('-')) return false;
  return !reservedTopLevelWords.contains(first);
}

/// `modular_cli_sdk`'s text-mode error line, exactly as
/// `ModularCli._renderRecordedError` writes it: `Error: <message> [<id>]`.
/// The `id` is matched, not assumed, so this only ever rewrites a line it
/// has actually confirmed is `extra-argument`, never a differently worded
/// line that happens to start the same way.
final RegExp _errorLinePattern = RegExp(r'^Error: .* \[([\w-]+)\]$');

/// Rewrites `modular_cli_sdk`'s own `extra-argument` message, recorded when
/// the bare `<program>` shortcut (spec section 4, G4) was given more than
/// one argument, into one that says what actually went wrong and how to
/// fix it: the program was typed as several shell words instead of one
/// quoted string.
///
/// [errorText] is everything `cx` wrote to its error stream for this
/// invocation (`ModularCli.run`'s own text, buffered rather than written
/// straight to the real stream so this can run first; see
/// `runCalculatrixCli`). Only the first line, the one `Error: ... [id]`
/// line, is ever replaced; anything after it (a positional-argument usage
/// block, when `modular_cli_sdk` resolved one) is kept verbatim, since
/// AC8's "no other change" covers it too.
///
/// Leaves [errorText] untouched whenever either guard fails: [args] does
/// not look like an unquoted program ([looksLikeUnquotedProgram]), or the
/// recorded error is not actually `extra-argument` (some other rejection
/// that happens to share this one's argument count, for instance). The
/// error id and exit code this function's caller returns are never
/// changed, only this one line's wording.
String rewriteUnquotedProgramError(String errorText, List<String> args) {
  if (!looksLikeUnquotedProgram(args)) return errorText;

  final int firstLineEnd = errorText.indexOf('\n');
  final String firstLine = firstLineEnd == -1
      ? errorText
      : errorText.substring(0, firstLineEnd);
  final String rest = firstLineEnd == -1 ? '' : errorText.substring(firstLineEnd);

  final RegExpMatch? match = _errorLinePattern.firstMatch(firstLine);
  if (match == null || match.group(1) != 'extra-argument') return errorText;

  final String quoted = args.join(' ');
  final String rewrittenMessage =
      'cx received ${args.length} arguments; quote the program as one '
      "argument: cx '$quoted'";
  return 'Error: $rewrittenMessage [extra-argument]$rest';
}
