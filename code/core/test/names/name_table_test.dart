// Issue #70 (runbook-agent-usability.md D66, D67, step U5): the name table
// of core holds exactly the system constants pi, e and i, read-only.
import 'dart:math' as math;

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  final CalculatrixNameTable table = CalculatrixNameTable.standard;

  group('CalculatrixNameTable.standard', () {
    test('holds exactly pi, e and i', () {
      expect(table.bindings.map((CalculatrixNameBinding b) => b.name), <String>[
        'pi',
        'e',
        'i',
      ]);
    });

    test('pi has the alias π and the value math.pi, approximate', () {
      final CalculatrixNameBinding binding = table.lookup('pi')!;
      expect(binding.aliases, <String>['π']);
      expect(binding.value.isExact, isFalse);
      expect(binding.value.at(0, 0), math.pi);
    });

    test('e has no alias and the value math.e, approximate', () {
      final CalculatrixNameBinding binding = table.lookup('e')!;
      expect(binding.aliases, isEmpty);
      expect(binding.value.isExact, isFalse);
      expect(binding.value.at(0, 0), math.e);
    });

    test('i is exact [[0 -1] [1 0]]', () {
      final CalculatrixNameBinding binding = table.lookup('i')!;
      expect(binding.aliases, isEmpty);
      expect(binding.value.isExact, isTrue);
      expect(MatrixDisplayFormatter.text(binding.value), '[[0 -1] [1 0]]');
    });

    test('lookup is case-insensitive and resolves aliases', () {
      expect(table.lookup('PI')!.name, 'pi');
      expect(table.lookup('Pi')!.name, 'pi');
      expect(table.lookup('E')!.name, 'e');
      expect(table.lookup('I')!.name, 'i');
      expect(table.lookup('π')!.name, 'pi');
    });

    test('lookup finds nothing for any other name', () {
      for (final String name in <String>['x', 'pii', 'e3', '2e', '', 'dup']) {
        expect(table.lookup(name), isNull, reason: name);
      }
    });

    test('every binding is read-only', () {
      for (final CalculatrixNameBinding binding in table.bindings) {
        expect(binding.readOnly, isTrue, reason: binding.name);
      }
    });

    test('the bindings list cannot be modified', () {
      expect(
        () => table.bindings.add(table.bindings.first),
        throwsUnsupportedError,
      );
    });

    test('every word is the name or an alias of a binding', () {
      expect(table.words, <String>['pi', 'π', 'e', 'i']);
    });
  });

  group('registry and name table agree (D66)', () {
    final CalculatrixCommandRegistry registry =
        CalculatrixCommandRegistry.standard;

    test('every binding name and alias has exactly one registry entry, in '
        'the constants category, primitive, arity 0', () {
      for (final CalculatrixNameBinding binding in table.bindings) {
        final CalculatrixCommandEntry entry = registry.lookup(binding.name)!;
        expect(entry.name, binding.name);
        expect(entry.aliases, binding.aliases);
        expect(entry.category, CalculatrixCommandCategory.constants);
        expect(entry.isPrimitive, isTrue);
        expect(entry.arity, 0);
        for (final String alias in binding.aliases) {
          expect(identical(registry.lookup(alias), entry), isTrue);
        }
      }
    });

    test('no other registry entry has a name or alias equal to a binding '
        'name or alias', () {
      final Set<String> bound = table.words
          .map((String word) => word.toLowerCase())
          .toSet();
      for (final CalculatrixCommandEntry entry in registry.entries) {
        if (table.lookup(entry.name) != null) {
          continue;
        }
        for (final String word in entry.words) {
          expect(
            bound.contains(word.toLowerCase()),
            isFalse,
            reason: '${entry.name}: $word',
          );
        }
      }
    });

    test('the constants entries are exactly the bindings', () {
      final List<String> constants = registry.entries
          .where(
            (CalculatrixCommandEntry e) =>
                e.category == CalculatrixCommandCategory.constants,
          )
          .map((CalculatrixCommandEntry e) => e.name)
          .toList();
      expect(constants, <String>['pi', 'e', 'i']);
    });

    test('an entry pushes the value read from the name table', () {
      for (final CalculatrixNameBinding binding in table.bindings) {
        final List<Matrix> stack = Calculatrix.evaluateRpnStack(<String>[
          binding.name,
        ]);
        expect(stack.single, same(binding.value), reason: binding.name);
      }
    });

    test('the entries document value, exactness and HP 50g reference', () {
      final Map<String, String> reference = <String, String>{
        'pi': 'π',
        'e': 'e',
        'i': 'i',
      };
      for (final String name in reference.keys) {
        final CalculatrixCommandEntry entry = registry.lookup(name)!;
        expect(entry.hp50gReference, reference[name]);
        expect(entry.stackEffect, '-> $name');
        expect(
          entry.description.toLowerCase(),
          contains(name == 'i' ? 'exact' : 'approximate'),
        );
      }
      expect(
        registry
            .lookup('pi')!
            .examples
            .map((CalculatrixCommandExample e) => e.program)
            .toList(),
        <String>['pi'],
      );
      expect(
        registry
            .lookup('i')!
            .examples
            .map((CalculatrixCommandExample e) => e.program)
            .toList(),
        <String>['i', 'i dup *', '3 4 i * +'],
      );
    });

    test('the suggestions for pii include pi', () {
      expect(registry.suggest('pii'), contains('pi'));
    });
  });
}
