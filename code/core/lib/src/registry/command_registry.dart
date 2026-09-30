import '../errors/errors.dart';
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
    this.hp50gEquivalent,
    required this.category,
    required this.stackEffect,
    this.preconditions,
    required this.description,
    this.examples = const <CalculatrixCommandExample>[],
    this.errors = const <CalculatrixErrorId>[],
    this.seeAlso = const <String>[],
    required this.build,
  });

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

  /// The closest HP 50g command name, or null when there is none.
  final String? hp50gEquivalent;

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
  /// entry. A factory function rather than a stored instance: every
  /// command registered so far is itself a stateless `const`, so building
  /// one fresh per lookup costs nothing, and the shape already
  /// accommodates a future parameterized command without changing this
  /// field's type.
  final CalculatrixCommand Function() build;

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
  /// AC5). A silent shadowing here would make `_compileRpnToken`
  /// non-deterministic about which entry's command actually runs for a
  /// given word.
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

    return CalculatrixCommandRegistry._(ordered, byWord);
  }

  CalculatrixCommandRegistry._(this.entries, this._byWord);

  /// Every registered entry, in registration order.
  final List<CalculatrixCommandEntry> entries;

  final Map<String, CalculatrixCommandEntry> _byWord;

  /// Resolves `word` to its entry by name or alias, case-insensitively, or
  /// null when `word` is not in the registry. Never resolves a search term
  /// (issue #32, AC4).
  CalculatrixCommandEntry? lookup(String word) => _byWord[word.toLowerCase()];

  /// The registry of every word `_compileRpnToken` recognizes today (issue
  /// #32): the operators the RPN compiler used to resolve through its own
  /// hardcoded switch, with no new math. Follow-up PRs add `vector`,
  /// `rows`, `append-rows`, `append-cols` and the rest of spec section 7.
  static final CalculatrixCommandRegistry
  standard = CalculatrixCommandRegistry(<CalculatrixCommandEntry>[
    CalculatrixCommandEntry(
      name: '+',
      searchTerms: const <String>['add', 'plus', 'sum'],
      hp50gEquivalent: '+',
      category: CalculatrixCommandCategory.arithmetic,
      stackEffect: 'A B -> A+B',
      preconditions:
          'A and B have the same shape, or either is a scalar '
          '(1x1)',
      description: 'Adds A and B element-wise.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('2 3 +', Matrix.scalar(5)),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.dimensionMismatch],
      seeAlso: const <String>['-'],
      build: () => const AddCommand(),
    ),
    CalculatrixCommandEntry(
      name: '-',
      searchTerms: const <String>['subtract', 'minus', 'difference'],
      hp50gEquivalent: '-',
      category: CalculatrixCommandCategory.arithmetic,
      stackEffect: 'A B -> A-B',
      preconditions:
          'A and B have the same shape, or either is a scalar '
          '(1x1)',
      description: 'Subtracts B from A element-wise.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('5 3 -', Matrix.scalar(2)),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.dimensionMismatch],
      seeAlso: const <String>['+'],
      build: () => const SubtractCommand(),
    ),
    CalculatrixCommandEntry(
      name: '*',
      searchTerms: const <String>['multiply', 'times', 'product'],
      hp50gEquivalent: '*',
      category: CalculatrixCommandCategory.arithmetic,
      stackEffect: 'A B -> A*B',
      preconditions: "A's columns equal B's rows, or either is a scalar (1x1)",
      description:
          'Multiplies A by B: matrix product, or scaling when either is '
          'a scalar.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('4 5 *', Matrix.scalar(20)),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.dimensionMismatch],
      seeAlso: const <String>['/'],
      build: () => const MultiplyCommand(),
    ),
    CalculatrixCommandEntry(
      name: '/',
      searchTerms: const <String>['divide', 'quotient'],
      hp50gEquivalent: '/',
      category: CalculatrixCommandCategory.arithmetic,
      stackEffect: 'A B -> A/B',
      preconditions: 'B is a scalar (1x1) and not zero',
      description: 'Divides A by the scalar B.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('10 4 /', Matrix.scalar(2.5)),
      ],
      errors: const <CalculatrixErrorId>[
        CalculatrixErrorId.typeMismatch,
        CalculatrixErrorId.nonFinite,
      ],
      seeAlso: const <String>['*'],
      build: () => const DivideCommand(),
    ),
    CalculatrixCommandEntry(
      name: '√',
      searchTerms: const <String>['sqrt', 'root', 'square-root'],
      hp50gEquivalent: '√',
      category: CalculatrixCommandCategory.arithmetic,
      stackEffect: 'X -> sqrt(X)',
      preconditions: 'X is square (a scalar is 1x1, and therefore square)',
      description:
          'The principal square root of X; a negative scalar gives the '
          'imaginary unit scaled accordingly.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('9 √', Matrix.scalar(3)),
      ],
      errors: const <CalculatrixErrorId>[CalculatrixErrorId.dimensionMismatch],
      seeAlso: const <String>['power'],
      build: () => const SqrtCommand(),
    ),
    CalculatrixCommandEntry(
      name: '%',
      searchTerms: const <String>['percent'],
      hp50gEquivalent: '%',
      category: CalculatrixCommandCategory.arithmetic,
      stackEffect: 'X -> X/100',
      description: 'X as a fraction of 100, e.g. "50 %" gives 0.5.',
      examples: <CalculatrixCommandExample>[
        CalculatrixCommandExample('50 %', Matrix.scalar(0.5)),
      ],
      build: () => const PercentCommand(),
    ),
    CalculatrixCommandEntry(
      name: 'power',
      aliases: const <String>['pwr', '^'],
      searchTerms: const <String>['exponent', 'raise'],
      hp50gEquivalent: '^',
      category: CalculatrixCommandCategory.arithmetic,
      stackEffect: 'B Y -> B^Y',
      preconditions:
          'B and Y are square (a scalar is square); when neither is a '
          'scalar they have the same size (runbook D25 has the full case '
          'table)',
      description:
          'Raises B to the power Y (runbook D25): '
          'B^Y = exp(Y . log B).',
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
      seeAlso: const <String>['√'],
      build: () => const PowerCommand(),
    ),
  ]);
}
