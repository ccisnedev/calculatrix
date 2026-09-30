import '../errors/errors.dart';
import '../evaluation/calculatrix.dart';
import '../machine/calculatrix_command.dart';
import '../machine/commands.dart';
import '../matrix/matrix.dart';

/// Categories of the core command registry (spec section 7): a closed,
/// machine-checkable set, so a caller such as `cx commands list --category`
/// (deferred to a follow-up PR) can validate its argument against the
/// registry itself instead of an arbitrary string (spec section 7,
/// "the categories are an enumeration taken from the registry").
enum CalculatrixCommandCategory { arithmetic }

/// One example RPN program from a registry entry's documentation (spec
/// section 7, "Examples"). Executable, not prose: a core test runs every
/// registered example and compares its result, so an entry's documentation
/// cannot drift from what the command actually does (issue #32, AC6).
final class CalculatrixCommandExample {
  const CalculatrixCommandExample(this.program, this.expected);

  /// The RPN program to run, e.g. "2 3 pwr". Tokenized the same way any
  /// other RPN input is (see [Calculatrix.tokenizeRpnLine]), so a
  /// space-separated matrix literal in an example is not split apart.
  final String program;

  /// The single value [program] must leave on the stack.
  final Matrix expected;
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
      preconditions:
          'A and B have the same shape, or either is a scalar '
          '(1x1)',
      description: 'Adds A and B element-wise.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('2 3 +', Matrix.scalar(5)),
        CalculatrixCommandExample('2 3 add', Matrix.scalar(5)),
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
      preconditions:
          'A and B have the same shape, or either is a scalar '
          '(1x1)',
      description: 'Subtracts B from A element-wise.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('5 3 -', Matrix.scalar(2)),
        CalculatrixCommandExample('5 3 subtract', Matrix.scalar(2)),
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
      preconditions: "A's columns equal B's rows, or either is a scalar (1x1)",
      description:
          'Multiplies A by B: matrix product, or scaling when either is '
          'a scalar.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('4 5 *', Matrix.scalar(20)),
        CalculatrixCommandExample('4 5 multiply', Matrix.scalar(20)),
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
      preconditions: 'B is a scalar (1x1) and not zero',
      description: 'Divides A by the scalar B.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('10 4 /', Matrix.scalar(2.5)),
        CalculatrixCommandExample('10 4 divide', Matrix.scalar(2.5)),
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
      preconditions: 'X is square (a scalar is 1x1, and therefore square)',
      description:
          'The principal square root of X (0.5 power, runbook D43, D44); '
          'a negative scalar gives the imaginary unit scaled accordingly.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('9 sqrt', Matrix.scalar(3)),
        CalculatrixCommandExample('9 √', Matrix.scalar(3)),
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
      preconditions: 'A is square and not singular',
      description:
          'The inverse of A (-1 power, runbook D43, D44): A times its '
          'inverse gives the identity.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample(
          '[[2 0] [0 4]] inverse',
          Matrix(<List<double>>[
            <double>[0.5, 0],
            <double>[0, 0.25],
          ]),
        ),
        CalculatrixCommandExample(
          '[[2 0] [0 4]] inv',
          Matrix(<List<double>>[
            <double>[0.5, 0],
            <double>[0, 0.25],
          ]),
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
      description: 'X as a fraction of 100, e.g. "50 %" gives 0.5.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('50 %', Matrix.scalar(0.5)),
        CalculatrixCommandExample('50 percent', Matrix.scalar(0.5)),
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
      preconditions:
          'B and Y are square (a scalar is square); when neither is a '
          'scalar they have the same size (runbook D25 has the full case '
          'table)',
      description:
          'Raises B to the power Y (runbook D25): '
          'B^Y = exp(Y . log B). Exponent -1 and 0.5 use the exact '
          'inverse and square-root algorithms instead (runbook D44); '
          'inverse and sqrt are defined in terms of this word.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('2 3 pwr', Matrix.scalar(8)),
        CalculatrixCommandExample('2 3 POWER', Matrix.scalar(8)),
        CalculatrixCommandExample('2 3 ^', Matrix.scalar(8)),
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
  ]);
}
