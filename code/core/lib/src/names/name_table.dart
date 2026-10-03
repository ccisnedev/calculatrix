import 'dart:math' as math;

import '../exact/rational.dart';
import '../matrix/matrix.dart';

/// One binding of the [CalculatrixNameTable]: a name, its aliases, the
/// value it stands for, and whether the binding is read-only (issue #70,
/// runbook-agent-usability.md D65).
final class CalculatrixNameBinding {
  const CalculatrixNameBinding({
    required this.name,
    this.aliases = const <String>[],
    required this.value,
    this.readOnly = true,
  });

  /// The name, e.g. `pi`. Matched case-insensitively.
  final String name;

  /// Other spellings of the same name, e.g. `π` for `pi`.
  final List<String> aliases;

  /// The value the name stands for.
  final Matrix value;

  /// Whether the binding can never be changed. Every system constant is.
  final bool readOnly;

  /// The name followed by its aliases.
  Iterable<String> get words => <String>[name, ...aliases];
}

/// The name table of core (issue #70, runbook-agent-usability.md D65): maps
/// a name, case-insensitively like the words of the registry, to a
/// [CalculatrixNameBinding]. RPN and infix resolve names through it.
///
/// [standard] holds exactly the system constants `pi` (alias `π`), `e` and
/// `i`, all read-only. There is no way to add a binding at run time:
/// variables and programs belong to issue #79.
final class CalculatrixNameTable {
  CalculatrixNameTable._(Iterable<CalculatrixNameBinding> bindings)
    : bindings = List<CalculatrixNameBinding>.unmodifiable(bindings),
      _byWord = <String, CalculatrixNameBinding>{
        for (final CalculatrixNameBinding binding in bindings)
          for (final String word in binding.words) word.toLowerCase(): binding,
      };

  /// The system constants. `i` is the exact matrix `[[0 -1] [1 0]]`; `pi`
  /// and `e` are the approximate doubles [math.pi] and [math.e].
  static final CalculatrixNameTable standard = CalculatrixNameTable._(
    <CalculatrixNameBinding>[
      CalculatrixNameBinding(
        name: 'pi',
        aliases: const <String>['π'],
        value: Matrix.scalar(math.pi),
      ),
      CalculatrixNameBinding(name: 'e', value: Matrix.scalar(math.e)),
      CalculatrixNameBinding(
        name: 'i',
        value: Matrix.exact(<List<Rational>>[
          <Rational>[Rational(BigInt.zero), Rational(-BigInt.one)],
          <Rational>[Rational(BigInt.one), Rational(BigInt.zero)],
        ]),
      ),
    ],
  );

  /// Every binding, in table order.
  final List<CalculatrixNameBinding> bindings;

  final Map<String, CalculatrixNameBinding> _byWord;

  /// The binding [name] resolves to, by name or alias, case-insensitively,
  /// or null when [name] is not in the table.
  CalculatrixNameBinding? lookup(String name) => _byWord[name.toLowerCase()];

  /// Every name and alias, binding by binding.
  Iterable<String> get words =>
      bindings.expand((CalculatrixNameBinding binding) => binding.words);
}
