import '../errors/errors.dart';
import '../evaluation/calculatrix.dart';
import '../evaluation/literals.dart';
import '../exact/exact_arithmetic.dart';
import '../machine/calculatrix_command.dart';
import '../machine/commands.dart';
import '../matrix/matrix.dart';

/// Categories of the core command registry (spec section 7): a closed,
/// machine-checkable set, so a caller such as `cx commands list --category`
/// (deferred to a follow-up PR) can validate its argument against the
/// registry itself instead of an arbitrary string (spec section 7,
/// "the categories are an enumeration taken from the registry").
///
/// `stack`, `construction`, `structure` and `linearAlgebra` follow the
/// grouping the runbook itself uses for the rest of the core vocabulary
/// (D46, "stack, construction, structure and linear algebra words"); the
/// S4c structure words (`vector`, `rows`, `append-cols`, `append-rows`)
/// registered earlier keep their existing `matrix` category, unchanged,
/// since D46 does not ask for them to be recategorized.
enum CalculatrixCommandCategory {
  arithmetic,
  matrix,
  stack,
  construction,
  structure,
  linearAlgebra,
}

/// The value [literal] spells, as `cx` itself reads it: `5` and
/// `[[1/2 0] [0 1/4]]` are exact, `~4` is approximate (runbook D49, D50,
/// D56). Examples state their expected values this way so the exactness
/// `cx commands show` prints is the exactness the program gives (issue #66).
Matrix _value(String literal) =>
    Literals.parse(literal, maxDigits: ExactArithmetic.defaultMaxDigits)!;

/// One example RPN program from a registry entry's documentation (spec
/// section 7, "Examples"). Executable, not prose: a core test runs every
/// registered example and compares its result, so an entry's documentation
/// cannot drift from what the command actually does (issue #32, AC6).
final class CalculatrixCommandExample {
  /// An example whose program leaves a single value on the stack.
  CalculatrixCommandExample(this.program, Matrix expected)
    : expectedStack = <Matrix>[expected];

  /// An example whose program leaves several values on the stack, bottom to
  /// top (e.g. `rows`, issue #37, AC3: `[[1 2] [3 4]] rows` leaves three
  /// values, not one).
  CalculatrixCommandExample.stack(this.program, this.expectedStack);

  /// The RPN program to run, e.g. "2 3 pwr". Tokenized the same way any
  /// other RPN input is (see [Calculatrix.tokenizeRpnLine]), so a
  /// space-separated matrix literal in an example is not split apart.
  final String program;

  /// The full stack [program] must leave, bottom to top.
  final List<Matrix> expectedStack;

  /// The single value [program] must leave on the stack. Only meaningful
  /// when [expectedStack] holds exactly one value.
  Matrix get expected => expectedStack.single;
}

/// One entry of the core command registry (spec section 7): the fields the
/// encyclopedia (`cx commands`, deferred to a follow-up PR) and the app's
/// long-press help need to find a word, resolve its aliases, and document
/// what it does, plus how to build the [CalculatrixCommand] the RPN
/// compiler executes for it. Living in core, not the CLI, because the app
/// needs the very same vocabulary (issue #32 problem statement).
final class CalculatrixCommandEntry {
  CalculatrixCommandEntry({
    required this.name,
    this.aliases = const <String>[],
    this.searchTerms = const <String>[],
    this.hp50gReference,
    this.definition,
    required this.category,
    required this.stackEffect,
    this.arity,
    this.preconditions,
    required this.description,
    this.examples = const <CalculatrixCommandExample>[],
    this.errors = const <CalculatrixErrorId>[],
    this.seeAlso = const <String>[],
    this.build,
  }) : assert(
         (definition == null) != (build == null),
         'A command entry is either primitive (build, no definition) or '
         'defined (definition, no build), never both or neither.',
       );

  /// The word of the language that resolves to this entry, e.g. "power".
  /// Matched case-insensitively by [CalculatrixCommandRegistry.lookup].
  final String name;

  /// Other words of the language that resolve to the same entry, e.g.
  /// "pwr" and "^" for "power" (runbook D14, D18). Unlike [searchTerms], an
  /// alias is itself a word of the language: it can appear in an RPN
  /// program (spec section 7, "Aliases and search terms are different
  /// things").
  final List<String> aliases;

  /// Terms that find this entry in `cx commands search` (deferred to a
  /// follow-up PR), but are never words of the language: using one in a
  /// program raises `unknown-word` (spec section 7, runbook D29).
  final List<String> searchTerms;

  /// The closest HP 50g command name, or null when there is none. Purely
  /// informative (runbook D42, "the HP 50g is inspiration, not adoption"):
  /// never resolved by [CalculatrixCommandRegistry.lookup], so an HP-only
  /// spelling such as "->ARRY" is never a name or alias of any entry.
  final String? hp50gReference;

  /// The RPN program over other words of the registry that defines this
  /// entry, or null when the entry is primitive (spec section 7,
  /// "Definition"; runbook D43), e.g. `inverse` is defined as `-1 power`.
  /// [CalculatrixCommandRegistry] validates, at construction, that every
  /// non-literal word a definition uses resolves in the registry and that
  /// no definition reaches itself, directly or through other defined
  /// words (issue #35, AC5).
  final String? definition;

  /// Whether this entry builds a core command directly rather than being
  /// defined by an RPN program (runbook D43).
  bool get isPrimitive => definition == null;

  /// The registry category this entry belongs to (spec section 7).
  final CalculatrixCommandCategory category;

  /// How the entry reads and leaves the stack, HP style, e.g. "B Y -> B^Y".
  final String stackEffect;

  /// How many values this word takes from the stack, counted on the
  /// user-facing word itself rather than on whatever primitives its
  /// expansion happens to call. Null for a word whose arity is only known
  /// at run time (e.g. `vector`, `pick`, `roll`), which already report
  /// their own accurate `needed`/`found` and need no pre-check here. Set
  /// for every other word so the evaluator can check the real stack depth
  /// against it before expanding a defined word's program, instead of
  /// letting an inner primitive's own (possibly inflated, for a defined
  /// word that pushes a literal before calling it) pop count leak into the
  /// user-facing error (issue #51, AC5).
  final int? arity;

  /// What must hold of the operands for the command to succeed, beyond
  /// having enough of them on the stack, or null when there is none.
  final String? preconditions;

  /// A short prose description of what the command does.
  final String description;

  /// Executable examples (spec section 7, AC6).
  final List<CalculatrixCommandExample> examples;

  /// The domain error ids (spec section 6) this command can raise.
  final List<CalculatrixErrorId> errors;

  /// Names of related entries, for cross-referencing in the encyclopedia.
  final List<String> seeAlso;

  /// Builds the [CalculatrixCommand] the RPN compiler executes for this
  /// entry, or null when the entry is defined rather than primitive
  /// (exactly one of [build] and [definition] is set; see [isPrimitive]).
  /// A factory function rather than a stored instance: every primitive
  /// command registered so far is itself a stateless `const`, so building
  /// one fresh per lookup costs nothing, and the shape already
  /// accommodates a future parameterized command without changing this
  /// field's type.
  final CalculatrixCommand Function()? build;

  /// Every word this entry resolves from: its name plus its aliases. Used
  /// by [CalculatrixCommandRegistry] to build and validate its lookup
  /// table, so the casing rule (case-insensitive) lives in one place.
  Iterable<String> get words => <String>[name, ...aliases];
}

/// The core command registry (spec section 7): resolves the word of an RPN
/// program to the [CalculatrixCommandEntry] that documents it and builds
/// the [CalculatrixCommand] to execute, case-insensitively by name or
/// alias. Search terms are deliberately not resolved here (spec section 7,
/// "Aliases and search terms are different things"; issue #32, AC4):
/// `cx commands search` is the only thing that reads them.
final class CalculatrixCommandRegistry {
  /// Builds a registry from `entries`, rejecting at construction two
  /// entries that share a name or alias, case-insensitively (issue #32,
  /// AC5), and, once every word is known, rejecting a defined entry
  /// (runbook D43) whose definition uses a word outside the registry, or
  /// that reaches itself, directly or through other defined words (issue
  /// #35, AC5). A silent shadowing here would make `_compileWord`
  /// non-deterministic about which entry's command actually runs for a
  /// given word; an unresolved or cyclic definition would instead fail
  /// only much later, the first time some RPN program happened to expand
  /// it.
  factory CalculatrixCommandRegistry(
    Iterable<CalculatrixCommandEntry> entries,
  ) {
    final List<CalculatrixCommandEntry> ordered =
        List<CalculatrixCommandEntry>.unmodifiable(entries);
    final Map<String, CalculatrixCommandEntry> byWord =
        <String, CalculatrixCommandEntry>{};

    for (final CalculatrixCommandEntry entry in ordered) {
      for (final String word in entry.words) {
        final String key = word.toLowerCase();
        final CalculatrixCommandEntry? existing = byWord[key];
        if (existing != null) {
          throw ArgumentError(
            'Command registry conflict: "$word" is claimed by both '
            '"${existing.name}" and "${entry.name}".',
          );
        }
        byWord[key] = entry;
      }
    }

    // Definitions are validated only once every entry's words are known
    // (above), so a definition may reference an entry registered later in
    // `entries`: registration order never affects whether a definition
    // resolves.
    for (final CalculatrixCommandEntry entry in ordered) {
      if (entry.definition != null) {
        _requireResolvableDefinition(entry, byWord);
      }
    }
    for (final CalculatrixCommandEntry entry in ordered) {
      if (entry.definition != null) {
        _requireAcyclicDefinition(entry, byWord, <CalculatrixCommandEntry>{});
      }
    }

    return CalculatrixCommandRegistry._(ordered, byWord);
  }

  static void _requireResolvableDefinition(
    CalculatrixCommandEntry entry,
    Map<String, CalculatrixCommandEntry> byWord,
  ) {
    for (final String word in Calculatrix.tokenizeRpnLine(entry.definition!)) {
      if (Calculatrix.isLiteralToken(word)) {
        continue;
      }
      if (!byWord.containsKey(word.toLowerCase())) {
        throw ArgumentError(
          'Command registry error: the definition of "${entry.name}" '
          '("${entry.definition}") uses unknown word "$word".',
        );
      }
    }
  }

  // Depth-first search over the definition graph, `path` holding every
  // defined entry visited on the current chain from the original entry
  // (inclusive of `entry` itself once we recurse below): a cycle is
  // detected the moment a definition's own dependency chain revisits an
  // entry already on that chain, whether that is `entry` reaching itself
  // directly (a definition that names itself) or indirectly (through one
  // or more other defined words).
  static void _requireAcyclicDefinition(
    CalculatrixCommandEntry entry,
    Map<String, CalculatrixCommandEntry> byWord,
    Set<CalculatrixCommandEntry> path,
  ) {
    if (path.contains(entry)) {
      throw ArgumentError(
        'Command registry error: cyclic definition detected at '
        '"${entry.name}".',
      );
    }
    if (entry.definition == null) {
      return;
    }

    final Set<CalculatrixCommandEntry> nextPath = <CalculatrixCommandEntry>{
      ...path,
      entry,
    };
    for (final String word in Calculatrix.tokenizeRpnLine(entry.definition!)) {
      if (Calculatrix.isLiteralToken(word)) {
        continue;
      }
      final CalculatrixCommandEntry? dependency = byWord[word.toLowerCase()];
      if (dependency != null) {
        _requireAcyclicDefinition(dependency, byWord, nextPath);
      }
    }
  }

  CalculatrixCommandRegistry._(this.entries, this._byWord);

  /// Every registered entry, in registration order.
  final List<CalculatrixCommandEntry> entries;

  final Map<String, CalculatrixCommandEntry> _byWord;

  /// Resolves `word` to its entry by name or alias, case-insensitively, or
  /// null when `word` is not in the registry. Never resolves a search term
  /// (issue #32, AC4).
  CalculatrixCommandEntry? lookup(String word) => _byWord[word.toLowerCase()];

  /// "Did you mean" candidates for `word` (spec section 7, "Did you
  /// mean"): the names of entries whose name or alias is closest to
  /// `word`, by restricted edit distance (Damerau-OSA: insertion,
  /// deletion, substitution and adjacent transposition), within
  /// `maxDistance`. An exact match on a search term is a candidate too,
  /// ranked ahead of any distance-based match, because it names the entry
  /// precisely even though it is never itself a word of the language
  /// (`hcat` suggests `append-cols`).
  ///
  /// Independent of the CLI and of `modular_cli_sdk` on purpose (issue
  /// #41): the app's own RPN evaluator needs the very same suggestions
  /// without depending on a CLI package, so this cannot reuse
  /// `CommandCatalog.suggest`, and is instead its own small
  /// reimplementation of the same edit distance.
  ///
  /// Two entries equally close by raw edit distance are not necessarily
  /// equally good guesses: "pow" sits exactly 2 edits from "power" (insert
  /// "e" and "r"), but also from "rows" and from "rotate"'s alias "rot",
  /// which share almost none of its letters (issue #51, AC6). Once every
  /// candidate within `maxDistance` is found, only the closest tier (the
  /// minimum distance actually reached) is kept, and, within that tier, a
  /// candidate reached through a word that shares a prefix with the
  /// needle, either way around ("pow" is a prefix of "power"; "dup" is a
  /// prefix of "dupp"), is kept over one that is merely as close by raw
  /// distance alone, whenever at least one such prefix match exists in
  /// the tier.
  ///
  /// Returns at most `limit` names, closest first, then in registration
  /// order. Never suggests `word` itself: a word already in the registry
  /// has nothing to suggest.
  List<String> suggest(String word, {int maxDistance = 2, int limit = 3}) {
    final String needle = word.toLowerCase();
    if (_byWord.containsKey(needle)) {
      return const <String>[];
    }

    final List<String> exactSearchTermMatches = <String>[];
    final List<_CommandSuggestionCandidate> distanceMatches =
        <_CommandSuggestionCandidate>[];

    for (final CalculatrixCommandEntry entry in entries) {
      if (entry.searchTerms.any((String term) => term.toLowerCase() == needle)) {
        exactSearchTermMatches.add(entry.name);
        continue;
      }

      int? best;
      bool bestIsPrefixMatch = false;
      for (final String candidate in entry.words) {
        final String candidateLower = candidate.toLowerCase();
        final int distance = restrictedEditDistance(needle, candidateLower);
        final bool isPrefixMatch =
            needle.startsWith(candidateLower) ||
            candidateLower.startsWith(needle);
        if (best == null || distance < best) {
          best = distance;
          bestIsPrefixMatch = isPrefixMatch;
        } else if (distance == best && isPrefixMatch) {
          bestIsPrefixMatch = true;
        }
      }
      // Scaled down for a short needle: a bare maxDistance of 2 puts every
      // one-character symbolic alias ("+", "-", "*", "/", ...) within
      // reach of any other single character, so a one-letter typo such as
      // "e" would otherwise suggest "add", "subtract" and "multiply" by
      // nothing more than their symbols. A needle only gets the full
      // maxDistance once it is long enough that a match within it still
      // shares most of its letters with the candidate.
      final int effectiveMaxDistance = (needle.length - 1).clamp(
        0,
        maxDistance,
      );
      if (best != null && best <= effectiveMaxDistance) {
        distanceMatches.add(
          _CommandSuggestionCandidate(entry.name, best, bestIsPrefixMatch),
        );
      }
    }

    final List<_CommandSuggestionCandidate> tightened = _tightenToClosestTier(
      distanceMatches,
    );
    tightened.sort((a, b) => a.distance.compareTo(b.distance));

    final List<String> ranked = <String>[
      ...exactSearchTermMatches,
      for (final _CommandSuggestionCandidate candidate in tightened)
        candidate.name,
    ];

    final List<String> deduped = <String>[];
    for (final String name in ranked) {
      if (!deduped.contains(name)) {
        deduped.add(name);
      }
    }
    return deduped.length <= limit ? deduped : deduped.sublist(0, limit);
  }

  // Keeps only the minimum-distance tier of `candidates`, then, within that
  // tier, only the prefix-related candidates when at least one of them is
  // prefix-related (see suggest's own doc comment for why: raw edit
  // distance alone cannot tell "power" apart from "rows" or "rot" for the
  // needle "pow", all three being exactly 2 edits away).
  static List<_CommandSuggestionCandidate> _tightenToClosestTier(
    List<_CommandSuggestionCandidate> candidates,
  ) {
    if (candidates.isEmpty) {
      return candidates;
    }

    int minDistance = candidates.first.distance;
    for (final _CommandSuggestionCandidate candidate in candidates) {
      if (candidate.distance < minDistance) {
        minDistance = candidate.distance;
      }
    }

    final List<_CommandSuggestionCandidate> closestTier = candidates
        .where((_CommandSuggestionCandidate c) => c.distance == minDistance)
        .toList();

    final bool anyPrefixMatch = closestTier.any(
      (_CommandSuggestionCandidate c) => c.isPrefixMatch,
    );
    if (!anyPrefixMatch) {
      return closestTier;
    }
    return closestTier
        .where((_CommandSuggestionCandidate c) => c.isPrefixMatch)
        .toList();
  }

  /// The registry of every word `_compileWord` recognizes today (issue
  /// #32): the operators the RPN compiler used to resolve through its own
  /// hardcoded switch, with no new math. Names are words of the language
  /// and their historical symbols are aliases (runbook D41); `inverse` and
  /// `sqrt` are defined words (`-1 power` and `0.5 power`, runbook D43,
  /// D44, issue #35), so `power` is the one implementation both of them
  /// share for an exact exponent. Follow-up PRs add `vector`, `rows`,
  /// `append-rows`, `append-cols` and the rest of spec section 7.
  static final CalculatrixCommandRegistry
  standard = CalculatrixCommandRegistry(<CalculatrixCommandEntry>[
    CalculatrixCommandEntry(
      name: 'add',
      aliases: const <String>['+'],
      searchTerms: const <String>['plus', 'sum'],
      hp50gReference: '+',
      category: CalculatrixCommandCategory.arithmetic,
      stackEffect: 'A B -> A+B',
      arity: 2,
      preconditions:
          'A and B have the same shape, or either is a scalar '
          '(1x1)',
      description: 'Adds A and B element-wise.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('2 3 +', _value('5')),
        CalculatrixCommandExample('2 3 add', _value('5')),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.dimensionMismatch],
      seeAlso: const <String>['subtract'],
      build: () => const AddCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'subtract',
      aliases: const <String>['-'],
      searchTerms: const <String>['minus', 'difference'],
      hp50gReference: '-',
      category: CalculatrixCommandCategory.arithmetic,
      stackEffect: 'A B -> A-B',
      arity: 2,
      preconditions:
          'A and B have the same shape, or either is a scalar '
          '(1x1)',
      description: 'Subtracts B from A element-wise.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('5 3 -', _value('2')),
        CalculatrixCommandExample('5 3 subtract', _value('2')),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.dimensionMismatch],
      seeAlso: const <String>['add'],
      build: () => const SubtractCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'multiply',
      aliases: const <String>['*'],
      searchTerms: const <String>['times', 'product'],
      hp50gReference: '*',
      category: CalculatrixCommandCategory.arithmetic,
      stackEffect: 'A B -> A*B',
      arity: 2,
      preconditions: "A's columns equal B's rows, or either is a scalar (1x1)",
      description:
          'Multiplies A by B: matrix product, or scaling when either is '
          'a scalar.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('4 5 *', _value('20')),
        CalculatrixCommandExample('4 5 multiply', _value('20')),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.dimensionMismatch],
      seeAlso: const <String>['divide'],
      build: () => const MultiplyCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'divide',
      aliases: const <String>['/'],
      searchTerms: const <String>['quotient'],
      hp50gReference: '/',
      category: CalculatrixCommandCategory.arithmetic,
      stackEffect: 'A B -> A/B',
      arity: 2,
      preconditions: 'B is a scalar (1x1) and not zero',
      description: 'Divides A by the scalar B.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('10 4 /', _value('2.5')),
        CalculatrixCommandExample('10 4 divide', _value('2.5')),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.typeMismatch,
        CalculatrixErrorId.nonFinite,
      ],
      seeAlso: const <String>['multiply'],
      build: () => const DivideCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'sqrt',
      aliases: const <String>['√'],
      searchTerms: const <String>['root', 'square-root'],
      hp50gReference: '√',
      definition: '0.5 power',
      category: CalculatrixCommandCategory.arithmetic,
      stackEffect: 'X -> X^(1/2)',
      arity: 1,
      preconditions: 'X is square (a scalar is 1x1, and therefore square)',
      description:
          'The principal square root of X (0.5 power); '
          'a negative scalar gives the imaginary unit scaled accordingly.',
      // 0.5 power: runbook D43, D44.
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('9 sqrt', _value('3')),
        CalculatrixCommandExample('9 √', _value('3')),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.dimensionMismatch,
        CalculatrixErrorId.logUndefined,
      ],
      seeAlso: const <String>['power', 'inverse'],
    ),
    CalculatrixCommandEntry(
      name: 'inverse',
      aliases: const <String>['inv'],
      searchTerms: const <String>['reciprocal'],
      hp50gReference: 'INV',
      definition: '-1 power',
      category: CalculatrixCommandCategory.arithmetic,
      stackEffect: 'A -> A^-1',
      arity: 1,
      preconditions: 'A is square and not singular',
      description:
          'The inverse of A (-1 power): A times its '
          'inverse gives the identity.',
      // -1 power: runbook D43, D44.
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample(
          '[[2 0] [0 4]] inverse',
          _value('[[0.5 0] [0 0.25]]'),
        ),
        CalculatrixCommandExample(
          '[[2 0] [0 4]] inv',
          _value('[[0.5 0] [0 0.25]]'),
        ),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.singularMatrix,
        CalculatrixErrorId.dimensionMismatch,
      ],
      seeAlso: const <String>['power', 'sqrt'],
    ),
    CalculatrixCommandEntry(
      name: 'percent',
      aliases: const <String>['%'],
      hp50gReference: '%',
      category: CalculatrixCommandCategory.arithmetic,
      stackEffect: 'X -> X/100',
      arity: 1,
      description: 'X as a fraction of 100, e.g. "50 %" gives 0.5.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('50 %', _value('0.5')),
        CalculatrixCommandExample('50 percent', _value('0.5')),
      ],
      build: () => const PercentCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'power',
      aliases: const <String>['pwr', '^'],
      searchTerms: const <String>['exponent', 'raise'],
      hp50gReference: '^',
      category: CalculatrixCommandCategory.arithmetic,
      stackEffect: 'B Y -> B^Y',
      arity: 2,
      // The full case table for squareness and size matching lives in
      // runbook D25.
      preconditions:
          'B and Y are square (a scalar is square); when neither is a '
          'scalar they have the same size',
      description:
          'Raises B to the power Y. The result is exact when B and Y are '
          'exact and Y is an integer, or when Y is a fraction p/q and the '
          'root is rational; otherwise it is approximate, marked ~, '
          'computed as exp(Y . log B). Exponents -1 and 0.5 use the '
          'inverse and square-root algorithms; inverse and sqrt are '
          'defined in terms of this word.',
      // runbook D25 (the exp/log identity); runbook D44 (the -1 and 0.5
      // shortcuts); runbook-agent-usability.md D67 (exactness examples).
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('2 3 pwr', _value('8')),
        CalculatrixCommandExample('2 3 POWER', _value('8')),
        CalculatrixCommandExample('2 3 ^', _value('8')),
        CalculatrixCommandExample('2 -3 ^', _value('0.125')),
        CalculatrixCommandExample('8 1/3 ^', _value('2')),
        // The double the program gives, sqrt(2), which `cx` shows as
        // ~1.41421356237 (12 significant digits).
        CalculatrixCommandExample('2 0.5 ^', Matrix.scalar(1.4142135623730951)),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.dimensionMismatch,
        CalculatrixErrorId.logUndefined,
        CalculatrixErrorId.ambiguousPower,
        CalculatrixErrorId.nonFinite,
        CalculatrixErrorId.singularMatrix,
      ],
      seeAlso: const <String>['sqrt', 'inverse'],
      build: () => const PowerCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'vector',
      searchTerms: const <String>[],
      hp50gReference: '→ARRY',
      category: CalculatrixCommandCategory.matrix,
      stackEffect: 'x1 ... xn n -> [[x1] ... [xn]]',
      preconditions:
          'n is a non-negative integer scalar; the stack holds at least n '
          'more scalars below n',
      description:
          'Builds the n x 1 column matrix [[x1] ... [xn]] from the n '
          'scalars below the count n. "0 vector" raises '
          'dimension-mismatch: an empty matrix has no representation '
          '(Matrix itself rejects zero rows), so a zero-length vector is '
          'not buildable.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('0 1 2 vector', _value('[[0] [1]]')),
        CalculatrixCommandExample('5 1 vector', _value('5')),
        CalculatrixCommandExample('1 2 3 3 vector', _value('[[1] [2] [3]]')),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.typeMismatch,
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.dimensionMismatch,
      ],
      seeAlso: const <String>['rows', 'append-cols', 'append-rows'],
      build: () => const VectorCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'rows',
      searchTerms: const <String>[],
      hp50gReference: 'ROW→',
      category: CalculatrixCommandCategory.matrix,
      stackEffect: '[[...]] -> [row1] ... [rown] n',
      arity: 1,
      description:
          'Splits a matrix into its rows, each a 1 x m matrix, followed by '
          'the row count n at level 1. A scalar has a '
          'single row, itself.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample.stack('[[1 2] [3 4]] rows', <Matrix>[
          _value('[[1 2]]'),
          _value('[[3 4]]'),
          _value('2'),
        ]),
        CalculatrixCommandExample.stack('7 rows', <Matrix>[
          _value('7'),
          _value('1'),
        ]),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.stackUnderflow],
      seeAlso: const <String>['vector', 'append-rows'],
      build: () => const RowsCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'append-cols',
      searchTerms: const <String>['hcat', 'horzcat', 'concatenate', 'column'],
      category: CalculatrixCommandCategory.matrix,
      stackEffect: 'A B -> [A B]',
      arity: 2,
      preconditions: 'A and B have the same number of rows',
      description:
          'Places the columns of B to the right of A: a '
          'generalization of the single-column append to any matrix B of '
          'matching row count.',
      // Shares its implementation with the single-column append; runbook
      // D44.
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample(
          '0 1 2 vector -1 0 2 vector append-cols',
          _value('[[0 -1] [1 0]]'),
        ),
        CalculatrixCommandExample(
          '[[1 2] [3 4]] [[5 6 7] [8 9 10]] append-cols',
          _value('[[1 2 5 6 7] [3 4 8 9 10]]'),
        ),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.dimensionMismatch],
      seeAlso: const <String>['append-rows', 'vector'],
      build: () => const AppendColsCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'append-rows',
      searchTerms: const <String>['vcat', 'vertcat', 'concatenate', 'row'],
      category: CalculatrixCommandCategory.matrix,
      stackEffect: 'A B -> A over B',
      arity: 2,
      preconditions: 'A and B have the same number of columns',
      description:
          'Places the rows of B below A: a generalization '
          'of the single-row append to any matrix B of matching column '
          'count.',
      // Shares its implementation with the single-row append; runbook D44.
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample(
          '[[1 2]] [[3 4] [5 6]] append-rows',
          _value('[[1 2] [3 4] [5 6]]'),
        ),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.dimensionMismatch],
      seeAlso: const <String>['append-cols', 'vector', 'rows'],
      build: () => const AppendRowsCommand(),
    ),
    // The rest of the core vocabulary (issue #39, S4d): stack, construction,
    // structure and linear algebra words, plus exp and ln (runbook D46).
    // Every index below is 1-based; the words themselves convert to the
    // 0-based indices the underlying Matrix methods take (D46, AC2).
    CalculatrixCommandEntry(
      name: 'exp',
      hp50gReference: 'EXP',
      category: CalculatrixCommandCategory.arithmetic,
      stackEffect: 'X -> e^X',
      arity: 1,
      preconditions: 'X is square (a scalar is 1x1, and therefore square)',
      description: 'The matrix exponential of X (Matrix.exp).',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('0 exp', _value('1')),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.dimensionMismatch,
      ],
      seeAlso: const <String>['ln', 'power'],
      build: () => const ExpCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'ln',
      hp50gReference: 'LN',
      category: CalculatrixCommandCategory.arithmetic,
      stackEffect: 'X -> log(X)',
      arity: 1,
      preconditions: 'X is square (a scalar is 1x1, and therefore square)',
      description:
          'The principal matrix logarithm of X (Matrix.log); "log" stays '
          'free for base 10.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('1 ln', _value('0')),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.dimensionMismatch,
        CalculatrixErrorId.logUndefined,
      ],
      seeAlso: const <String>['exp', 'power'],
      build: () => const LnCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'negate',
      aliases: const <String>['neg'],
      hp50gReference: 'NEG',
      category: CalculatrixCommandCategory.arithmetic,
      stackEffect: 'A -> -A',
      arity: 1,
      description: 'Negates A element-wise.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('5 negate', _value('-5')),
        CalculatrixCommandExample('5 neg', _value('-5')),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.stackUnderflow],
      seeAlso: const <String>['subtract'],
      build: () => const NegateCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'approx',
      aliases: const <String>['num'],
      hp50gReference: '->NUM',
      searchTerms: const <String>[
        'decimal',
        'float',
        'numeric',
        'approximate',
        'literal',
        '~',
      ],
      category: CalculatrixCommandCategory.arithmetic,
      stackEffect: 'A -> ~A',
      arity: 1,
      description:
          'Makes A approximate: each entry becomes the nearest double. An '
          'approximate value is left unchanged. To type an approximate '
          'value directly, put ~ in front of the literal: ~0.1, ~-2, '
          '~[[1 2] [3 4]].',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample(
          '1 3 / approx',
          _value('~0.3333333333333333'),
        ),
        CalculatrixCommandExample('1 4 / num', _value('~0.25')),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.nonFinite,
      ],
      seeAlso: const <String>['exact'],
      build: () => const ApproxCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'exact',
      hp50gReference: '->Q',
      searchTerms: const <String>[
        'fraction',
        'rational',
        'literal',
        'decimal',
        'integer',
        'matrix literal',
        'exact by default',
      ],
      category: CalculatrixCommandCategory.arithmetic,
      stackEffect: '~A -> A',
      arity: 1,
      description:
          'Makes A exact: each entry becomes the simplest rational (smallest '
          'denominator) that rounds to the same double, so it never guesses '
          'beyond the precision of the double. An exact value is left '
          'unchanged. Values are exact unless marked ~, so literals need no '
          'conversion: integers of any size (3 40 ^ is '
          '12157665459056928801), decimals (0.1 is 1/10), fractions (1/3, '
          '-5/3) and matrices of them ([[1 1/2] [1/2 1/3]]).',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('1 3 / approx exact', _value('1/3')),
        CalculatrixCommandExample('0.1 approx exact', _value('0.1')),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.nonFinite,
      ],
      seeAlso: const <String>['approx'],
      build: () => const ExactCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'pick',
      hp50gReference: 'PICK',
      category: CalculatrixCommandCategory.stack,
      stackEffect: '... n -> ... (level n copied to the top)',
      preconditions:
          'n is a positive integer scalar (level 1 is the top); the stack '
          'holds at least n more values below n',
      description:
          'Copies the value at level n (1-based, level 1 is the top) to '
          'the top of the stack.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample.stack('1 2 3 3 pick', <Matrix>[
          _value('1'),
          _value('2'),
          _value('3'),
          _value('1'),
        ]),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.typeMismatch,
        CalculatrixErrorId.stackUnderflow,
      ],
      seeAlso: const <String>['roll', 'duplicate', 'over'],
      build: () => const PickWordCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'roll',
      hp50gReference: 'ROLL',
      category: CalculatrixCommandCategory.stack,
      stackEffect: '... n -> ... (level n moved to the top)',
      preconditions:
          'n is a positive integer scalar (level 1 is the top); the stack '
          'holds at least n more values below n',
      description:
          'Moves the value at level n (1-based, level 1 is the top) to the '
          'top of the stack.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample.stack('1 2 3 3 roll', <Matrix>[
          _value('2'),
          _value('3'),
          _value('1'),
        ]),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.typeMismatch,
        CalculatrixErrorId.stackUnderflow,
      ],
      seeAlso: const <String>['pick', 'swap', 'rotate'],
      build: () => const RollWordCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'drop',
      hp50gReference: 'DROP',
      category: CalculatrixCommandCategory.stack,
      stackEffect: 'A -> (removes level 1)',
      arity: 1,
      description: 'Removes the top of the stack.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample.stack('1 2 drop', <Matrix>[_value('1')]),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.stackUnderflow],
      seeAlso: const <String>['duplicate', 'pick', 'roll'],
      build: () => const DropCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'duplicate',
      aliases: const <String>['dup'],
      hp50gReference: 'DUP',
      definition: '1 pick',
      category: CalculatrixCommandCategory.stack,
      stackEffect: 'A -> A A',
      arity: 1,
      description: 'Duplicates the top of the stack (1 pick).',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample.stack('5 duplicate', <Matrix>[
          _value('5'),
          _value('5'),
        ]),
        CalculatrixCommandExample.stack('5 dup', <Matrix>[
          _value('5'),
          _value('5'),
        ]),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.stackUnderflow],
      seeAlso: const <String>['pick', 'over'],
    ),
    CalculatrixCommandEntry(
      name: 'over',
      hp50gReference: 'OVER',
      definition: '2 pick',
      category: CalculatrixCommandCategory.stack,
      stackEffect: 'A B -> A B A',
      arity: 2,
      description: 'Copies the second value from the top to the top (2 pick).',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample.stack('1 2 over', <Matrix>[
          _value('1'),
          _value('2'),
          _value('1'),
        ]),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.stackUnderflow],
      seeAlso: const <String>['pick', 'duplicate'],
    ),
    CalculatrixCommandEntry(
      name: 'swap',
      hp50gReference: 'SWAP',
      definition: '2 roll',
      category: CalculatrixCommandCategory.stack,
      stackEffect: 'A B -> B A',
      arity: 2,
      description: 'Swaps the top two values (2 roll).',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample.stack('1 2 swap', <Matrix>[
          _value('2'),
          _value('1'),
        ]),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.stackUnderflow],
      seeAlso: const <String>['roll', 'rotate'],
    ),
    CalculatrixCommandEntry(
      name: 'rotate',
      aliases: const <String>['rot'],
      hp50gReference: 'ROT',
      definition: '3 roll',
      category: CalculatrixCommandCategory.stack,
      stackEffect: 'A B C -> B C A',
      arity: 3,
      description: 'Rotates the top three values (3 roll).',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample.stack('1 2 3 rotate', <Matrix>[
          _value('2'),
          _value('3'),
          _value('1'),
        ]),
        CalculatrixCommandExample.stack('1 2 3 rot', <Matrix>[
          _value('2'),
          _value('3'),
          _value('1'),
        ]),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.stackUnderflow],
      seeAlso: const <String>['roll', 'swap'],
    ),
    CalculatrixCommandEntry(
      name: 'zeros',
      hp50gReference: 'CON',
      category: CalculatrixCommandCategory.construction,
      stackEffect: 'r c -> [r x c zero matrix]',
      // No declared arity (issue #51, AC8): ZerosCommand pops and validates
      // c before it ever pops r, so with only one value on the stack a
      // negative or non-integer c must still report its own type-mismatch,
      // the way it did before the arity precheck existed. A fixed arity
      // here would short-circuit that check with a stack-underflow instead,
      // the one case the precheck must defer to the word itself on.
      preconditions: 'r and c are positive integer scalars',
      description:
          'Builds the r x c matrix of zeros (HP 50g CON with 0). "0 3 '
          'zeros" raises dimension-mismatch, like "0 vector".',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('2 3 zeros', _value('[[0 0 0] [0 0 0]]')),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.typeMismatch,
        CalculatrixErrorId.dimensionMismatch,
      ],
      seeAlso: const <String>['ones', 'identity'],
      build: () => const ZerosCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'ones',
      hp50gReference: 'CON',
      category: CalculatrixCommandCategory.construction,
      stackEffect: 'r c -> [r x c matrix of ones]',
      // No declared arity: see the same note on 'zeros' above (issue #51,
      // AC8).
      preconditions: 'r and c are positive integer scalars',
      description:
          'Builds the r x c matrix of ones (HP 50g CON with 1). "0 3 '
          'ones" raises dimension-mismatch, like "0 vector".',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('2 2 ones', _value('[[1 1] [1 1]]')),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.typeMismatch,
        CalculatrixErrorId.dimensionMismatch,
      ],
      seeAlso: const <String>['zeros', 'identity'],
      build: () => const OnesCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'identity',
      hp50gReference: 'IDN',
      category: CalculatrixCommandCategory.construction,
      stackEffect: 'n -> [n x n identity]',
      arity: 1,
      preconditions: 'n is a positive integer scalar',
      description:
          'Builds the n x n identity matrix. "0 identity" raises '
          'dimension-mismatch, like "0 vector".',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample(
          '3 identity',
          _value('[[1 0 0] [0 1 0] [0 0 1]]'),
        ),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.typeMismatch,
        CalculatrixErrorId.dimensionMismatch,
      ],
      seeAlso: const <String>['zeros', 'ones'],
      build: () => const IdentityCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'transpose',
      hp50gReference: 'TRN',
      category: CalculatrixCommandCategory.structure,
      stackEffect: 'A -> A^T',
      arity: 1,
      description: 'Transposes A.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample(
          '[[1 2] [3 4]] transpose',
          _value('[[1 3] [2 4]]'),
        ),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.stackUnderflow],
      seeAlso: const <String>['rows', 'append-cols', 'append-rows'],
      build: () => const TransposeCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'delete-row',
      hp50gReference: 'ROW-',
      category: CalculatrixCommandCategory.structure,
      stackEffect: 'A i -> A (row i removed)',
      // No declared arity: DeleteRowWordCommand pops and validates i
      // before it ever pops A, so the same note on 'zeros' above applies
      // (issue #51, AC8).
      preconditions: 'i is a 1-based row index of A',
      description: 'Removes row i of A (1-based).',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample(
          '[[1 2] [3 4]] 1 delete-row',
          _value('[[3 4]]'),
        ),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.typeMismatch,
        CalculatrixErrorId.dimensionMismatch,
      ],
      seeAlso: const <String>['delete-col', 'duplicate-row', 'move-row'],
      build: () => const DeleteRowWordCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'delete-col',
      hp50gReference: 'COL-',
      category: CalculatrixCommandCategory.structure,
      stackEffect: 'A j -> A (column j removed)',
      // No declared arity: see the note on 'delete-row' above (issue #51,
      // AC8).
      preconditions: 'j is a 1-based column index of A',
      description: 'Removes column j of A (1-based).',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample(
          '[[1 2] [3 4]] 1 delete-col',
          _value('[[2] [4]]'),
        ),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.typeMismatch,
        CalculatrixErrorId.dimensionMismatch,
      ],
      seeAlso: const <String>['delete-row', 'duplicate-col', 'move-col'],
      build: () => const DeleteColumnWordCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'duplicate-row',
      category: CalculatrixCommandCategory.structure,
      stackEffect: 'A i -> A (row i duplicated)',
      // No declared arity: see the note on 'delete-row' above (issue #51,
      // AC8).
      preconditions: 'i is a 1-based row index of A',
      description: 'Inserts a copy of row i right after it (1-based).',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample(
          '[[1 2] [3 4]] 1 duplicate-row',
          _value('[[1 2] [1 2] [3 4]]'),
        ),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.typeMismatch,
        CalculatrixErrorId.dimensionMismatch,
      ],
      seeAlso: const <String>['delete-row', 'duplicate-col'],
      build: () => const DuplicateRowWordCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'duplicate-col',
      category: CalculatrixCommandCategory.structure,
      stackEffect: 'A j -> A (column j duplicated)',
      // No declared arity: see the note on 'delete-row' above (issue #51,
      // AC8).
      preconditions: 'j is a 1-based column index of A',
      description:
          'Inserts a copy of column j right after it (1-based).',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample(
          '[[1 2] [3 4]] 1 duplicate-col',
          _value('[[1 1 2] [3 3 4]]'),
        ),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.typeMismatch,
        CalculatrixErrorId.dimensionMismatch,
      ],
      seeAlso: const <String>['delete-col', 'duplicate-row'],
      build: () => const DuplicateColumnWordCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'move-row',
      category: CalculatrixCommandCategory.structure,
      stackEffect: 'A i k -> A (row i moved to position k)',
      // No declared arity: MoveRowWordCommand pops and validates k, then
      // pops and validates i, before it ever pops A; same note on
      // 'delete-row' above (issue #51, AC8).
      preconditions: 'i and k are 1-based row indices of A',
      description: 'Moves row i to position k (1-based).',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample(
          '[[1 2] [3 4]] 2 1 move-row',
          _value('[[3 4] [1 2]]'),
        ),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.typeMismatch,
        CalculatrixErrorId.dimensionMismatch,
      ],
      seeAlso: const <String>['move-col', 'delete-row'],
      build: () => const MoveRowWordCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'move-col',
      category: CalculatrixCommandCategory.structure,
      stackEffect: 'A j k -> A (column j moved to position k)',
      // No declared arity: see the note on 'move-row' above (issue #51,
      // AC8).
      preconditions: 'j and k are 1-based column indices of A',
      description: 'Moves column j to position k (1-based).',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample(
          '[[1 2 3] [4 5 6]] 3 1 move-col',
          _value('[[3 1 2] [6 4 5]]'),
        ),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.typeMismatch,
        CalculatrixErrorId.dimensionMismatch,
      ],
      seeAlso: const <String>['move-row', 'delete-col'],
      build: () => const MoveColumnWordCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'determinant',
      aliases: const <String>['det'],
      hp50gReference: 'DET',
      category: CalculatrixCommandCategory.linearAlgebra,
      stackEffect: 'A -> det(A)',
      arity: 1,
      preconditions: 'A is square',
      description: 'The determinant of A.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('[[2 0] [0 3]] determinant', _value('6')),
        CalculatrixCommandExample('[[2 0] [0 3]] det', _value('6')),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.dimensionMismatch,
      ],
      seeAlso: const <String>['inverse', 'rank'],
      build: () => const DeterminantCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'trace',
      hp50gReference: 'TRACE',
      category: CalculatrixCommandCategory.linearAlgebra,
      stackEffect: 'A -> trace(A)',
      arity: 1,
      preconditions: 'A is square',
      description: 'The sum of the diagonal of A.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('[[1 2] [3 4]] trace', _value('5')),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.dimensionMismatch,
      ],
      seeAlso: const <String>['determinant'],
      build: () => const TraceCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'rank',
      hp50gReference: 'RANK',
      category: CalculatrixCommandCategory.linearAlgebra,
      stackEffect: 'A -> rank(A)',
      arity: 1,
      description: 'The rank of A.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('[[1 2] [2 4]] rank', _value('1')),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.stackUnderflow],
      seeAlso: const <String>['determinant', 'rref'],
      build: () => const RankCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'frobenius-norm',
      aliases: const <String>['norm'],
      hp50gReference: 'FNORM',
      category: CalculatrixCommandCategory.linearAlgebra,
      stackEffect: 'A -> ||A||_F',
      arity: 1,
      description: 'The Frobenius norm of A.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('[[3 4]] frobenius-norm', _value('5')),
        CalculatrixCommandExample('[[3 4]] norm', _value('5')),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.stackUnderflow],
      seeAlso: const <String>['spectral-norm'],
      build: () => const NormCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'spectral-norm',
      hp50gReference: 'SNRM',
      category: CalculatrixCommandCategory.linearAlgebra,
      stackEffect: 'A -> ||A||_2',
      arity: 1,
      description: 'The spectral (2-)norm of A: its largest singular value.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('[[3 0] [0 4]] spectral-norm', _value('~4')),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.stackUnderflow],
      seeAlso: const <String>['frobenius-norm'],
      build: () => const SpectralNormCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'eigenvalues',
      aliases: const <String>['eig'],
      hp50gReference: 'EGVL',
      category: CalculatrixCommandCategory.linearAlgebra,
      stackEffect: 'A -> [eigenvalues of A]',
      arity: 1,
      preconditions: 'A is square',
      description: 'The eigenvalues of A, as a column, descending.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample(
          '[[2 0] [0 3]] eigenvalues',
          _value('[[3] [2]]'),
        ),
        CalculatrixCommandExample('[[2 0] [0 3]] eig', _value('[[3] [2]]')),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.dimensionMismatch,
        CalculatrixErrorId.complexResult,
      ],
      seeAlso: const <String>['diagonalize'],
      build: () => const EigenvaluesCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'diagonalize',
      category: CalculatrixCommandCategory.linearAlgebra,
      stackEffect: 'A -> P D (A = P D P^-1, D on level 1)',
      arity: 1,
      preconditions: 'A is square, with a real spectrum',
      description:
          'Diagonalizes A: leaves the eigenvector matrix P and the '
          'diagonal eigenvalue matrix D, with D on top.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample.stack('[[3 0] [0 5]] diagonalize', <Matrix>[
          _value('~[[0 1] [1 0]]'),
          _value('~[[5 0] [0 3]]'),
        ]),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.dimensionMismatch,
        CalculatrixErrorId.complexResult,
      ],
      seeAlso: const <String>['eigenvalues'],
      build: () => const DiagonalizationCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'cofactors',
      category: CalculatrixCommandCategory.linearAlgebra,
      stackEffect: 'A -> [cofactor matrix of A]',
      arity: 1,
      preconditions: 'A is square',
      description: 'The cofactor matrix of A.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample(
          '[[1 2] [3 4]] cofactors',
          _value('[[4 -3] [-2 1]]'),
        ),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.dimensionMismatch,
      ],
      seeAlso: const <String>['adjugate', 'determinant'],
      build: () => const CofactorMatrixCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'adjugate',
      aliases: const <String>['adj'],
      category: CalculatrixCommandCategory.linearAlgebra,
      stackEffect: 'A -> adj(A)',
      arity: 1,
      preconditions: 'A is square',
      description: 'The adjugate of A: the transpose of its cofactor matrix.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample(
          '[[1 2] [3 4]] adjugate',
          _value('[[4 -2] [-3 1]]'),
        ),
        CalculatrixCommandExample(
          '[[1 2] [3 4]] adj',
          _value('[[4 -2] [-3 1]]'),
        ),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.dimensionMismatch,
      ],
      seeAlso: const <String>['cofactors', 'inverse'],
      build: () => const AdjugateCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'dot',
      hp50gReference: 'DOT',
      category: CalculatrixCommandCategory.linearAlgebra,
      stackEffect: 'A B -> A . B',
      arity: 2,
      preconditions: 'A and B are column vectors of the same dimension',
      description: 'The dot product of A and B.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample(
          '1 2 3 3 vector 4 5 6 3 vector dot',
          _value('32'),
        ),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.dimensionMismatch,
      ],
      seeAlso: const <String>['cross'],
      build: () => const DotProductCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'cross',
      hp50gReference: 'CROSS',
      category: CalculatrixCommandCategory.linearAlgebra,
      stackEffect: 'A B -> A x B',
      arity: 2,
      preconditions: 'A and B are 3x1 column vectors',
      description: 'The cross product of A and B.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample(
          '1 0 0 3 vector 0 1 0 3 vector cross',
          _value('[[0] [0] [1]]'),
        ),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.dimensionMismatch,
      ],
      seeAlso: const <String>['dot'],
      build: () => const CrossProductCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'rref',
      hp50gReference: 'RREF',
      category: CalculatrixCommandCategory.linearAlgebra,
      stackEffect: 'A -> rref(A)',
      arity: 1,
      description: 'The reduced row echelon form of A.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample(
          '[[1 2] [2 4]] rref',
          _value('[[1 2] [0 0]]'),
        ),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.stackUnderflow],
      seeAlso: const <String>['rank'],
      build: () => const RrefCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'lu',
      hp50gReference: 'LU',
      category: CalculatrixCommandCategory.linearAlgebra,
      stackEffect: 'A -> P L U (P A = L U, U on level 1)',
      arity: 1,
      preconditions: 'A is square',
      description:
          'The PLU decomposition of A: leaves the permutation P, the unit '
          'lower-triangular L and the upper-triangular U, with U on top.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample.stack('[[1 0] [0 1]] lu', <Matrix>[
          _value('[[1 0] [0 1]]'),
          _value('[[1 0] [0 1]]'),
          _value('[[1 0] [0 1]]'),
        ]),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.dimensionMismatch,
      ],
      seeAlso: const <String>['qr', 'determinant'],
      build: () => const LuDecompositionCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'qr',
      hp50gReference: 'QR',
      category: CalculatrixCommandCategory.linearAlgebra,
      stackEffect: 'A -> Q R (A = Q R, R on level 1)',
      arity: 1,
      preconditions: 'A has at least as many rows as columns',
      description:
          'The QR decomposition of A: leaves the orthogonal Q and the '
          'upper-triangular R, with R on top.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample.stack('[[1 0] [0 1]] qr', <Matrix>[
          _value('~[[1 0] [0 1]]'),
          _value('~[[1 0] [0 1]]'),
        ]),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.stackUnderflow,
        CalculatrixErrorId.dimensionMismatch,
      ],
      seeAlso: const <String>['lu'],
      build: () => const QrDecompositionCommand(),
    ),
  ]);
}

/// A [CalculatrixCommandRegistry.suggest] candidate: an entry name paired
/// with its edit distance to the word being looked up, and whether that
/// distance was reached through a word (the entry's name or one of its
/// aliases) that shares a prefix with the needle, either way around.
class _CommandSuggestionCandidate {
  _CommandSuggestionCandidate(this.name, this.distance, this.isPrefixMatch);

  final String name;
  final int distance;
  final bool isPrefixMatch;
}

/// Restricted edit distance (Damerau-OSA) between `a` and `b`: the minimum
/// number of insertions, deletions, substitutions and adjacent
/// transpositions of a single pair of characters needed to turn one into
/// the other. "Restricted" (optimal string alignment) because, unlike true
/// Damerau-Levenshtein, no substring is transposed more than once; that
/// difference never matters for the short, mostly-distinct command words
/// this compares.
///
/// A local, dependency-free reimplementation (issue #41, spec section 7,
/// "Did you mean"): core cannot depend on `modular_cli_sdk`, whose
/// `CommandCatalog` has the same algorithm for route suggestions.
///
/// Public (not `_`-prefixed) so `calculatrix_cli` can reuse this one
/// implementation instead of writing its own copy when it needs to score
/// whether a whole route name, not just one word of it, is genuinely close
/// to a typo (issue #51, AC6): the dependency runs the other way from the
/// one the comment above rules out, since the CLI package already depends
/// on this one.
int restrictedEditDistance(String a, String b) {
  final int lenA = a.length;
  final int lenB = b.length;
  if (lenA == 0) return lenB;
  if (lenB == 0) return lenA;

  final List<List<int>> distance = List<List<int>>.generate(
    lenA + 1,
    (int i) => List<int>.filled(lenB + 1, 0),
  );

  for (int i = 0; i <= lenA; i++) {
    distance[i][0] = i;
  }
  for (int j = 0; j <= lenB; j++) {
    distance[0][j] = j;
  }

  for (int i = 1; i <= lenA; i++) {
    for (int j = 1; j <= lenB; j++) {
      final int cost = a[i - 1] == b[j - 1] ? 0 : 1;
      int best = <int>[
        distance[i - 1][j] + 1, // deletion
        distance[i][j - 1] + 1, // insertion
        distance[i - 1][j - 1] + cost, // substitution (or match)
      ].reduce((int x, int y) => x < y ? x : y);

      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        final int transposition = distance[i - 2][j - 2] + 1;
        if (transposition < best) {
          best = transposition;
        }
      }

      distance[i][j] = best;
    }
  }

  return distance[lenA][lenB];
}
