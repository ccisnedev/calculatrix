import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('CalculatrixCommandRegistry.standard', () {
    test('resolves a name case-insensitively', () {
      final CalculatrixCommandEntry? entry = CalculatrixCommandRegistry.standard
          .lookup('ADD');

      expect(entry, isNotNull);
      expect(entry!.name, 'add');
    });

    test('resolves an alias case-insensitively', () {
      final CalculatrixCommandEntry? byPwr = CalculatrixCommandRegistry.standard
          .lookup('PWR');
      final CalculatrixCommandEntry? byCaret = CalculatrixCommandRegistry
          .standard
          .lookup('^');

      expect(byPwr?.name, 'power');
      expect(byCaret?.name, 'power');
    });

    test('returns null for an unknown word', () {
      expect(CalculatrixCommandRegistry.standard.lookup('frobnicate'), isNull);
    });

    test(
      'never resolves a search term: it only finds an entry, it is not a word',
      () {
        // "plus" is a search term of "add" (D41: names are words, symbols
        // are aliases), not one of its aliases: it must not resolve here,
        // and using it as an RPN word must raise unknown-word (AC4).
        final CalculatrixCommandEntry add = CalculatrixCommandRegistry.standard
            .lookup('add')!;
        expect(add.searchTerms, contains('plus'));
        expect(CalculatrixCommandRegistry.standard.lookup('plus'), isNull);

        expect(
          () => Calculatrix.evaluateRpn(<String>['2', '3', 'plus']),
          throwsA(
            isA<UnknownWordError>().having(
              (UnknownWordError error) => error.errorId,
              'errorId',
              CalculatrixErrorId.unknownWord,
            ),
          ),
        );
      },
    );

    test('exposes every field of a spec section 7 entry', () {
      final CalculatrixCommandEntry power = CalculatrixCommandRegistry.standard
          .lookup('power')!;

      expect(power.name, 'power');
      expect(power.aliases, containsAll(<String>['pwr', '^']));
      expect(power.category, CalculatrixCommandCategory.arithmetic);
      expect(power.stackEffect, isNotEmpty);
      expect(power.description, isNotEmpty);
      expect(power.examples, isNotEmpty);
      expect(power.errors, contains(CalculatrixErrorId.dimensionMismatch));
      expect(power.hp50gReference, '^');
      expect(power.definition, isNull);
      expect(power.isPrimitive, isTrue);
      expect(power.build!(), isA<PowerCommand>());
    });

    test('inverse and sqrt are defined words over power; every other entry '
        'is still primitive (D43, issue #35, AC2)', () {
      const Set<String> definedNames = <String>{'inverse', 'sqrt'};
      for (final CalculatrixCommandEntry entry
          in CalculatrixCommandRegistry.standard.entries) {
        if (definedNames.contains(entry.name)) {
          expect(entry.isPrimitive, isFalse, reason: entry.name);
          expect(entry.definition, isNotNull, reason: entry.name);
          expect(entry.build, isNull, reason: entry.name);
        } else {
          expect(entry.isPrimitive, isTrue, reason: entry.name);
          expect(entry.build, isNotNull, reason: entry.name);
        }
      }

      final CalculatrixCommandEntry inverse = CalculatrixCommandRegistry
          .standard
          .lookup('inverse')!;
      final CalculatrixCommandEntry sqrt = CalculatrixCommandRegistry.standard
          .lookup('sqrt')!;
      expect(inverse.definition, '-1 power');
      expect(sqrt.definition, '0.5 power');
    });

    test('no HP 50g reference is ever a name or alias (D42)', () {
      for (final CalculatrixCommandEntry entry
          in CalculatrixCommandRegistry.standard.entries) {
        final String? hp = entry.hp50gReference;
        if (hp == null) {
          continue;
        }
        for (final CalculatrixCommandEntry other
            in CalculatrixCommandRegistry.standard.entries) {
          if (other.name == entry.name) {
            // A symbol such as "^" may legitimately be both power's own
            // alias and its informative HP reference (D41, D42): the rule
            // is that an *HP-only* spelling (e.g. "->ARRY") is never a
            // word, not that an entry's alias can never equal its own HP
            // reference text.
            continue;
          }
          expect(
            other.words,
            isNot(contains(hp)),
            reason:
                '"$hp" (HP reference of "${entry.name}") must not be a '
                'name or alias of "${other.name}"',
          );
        }
      }
    });

    test('categories are an enumeration', () {
      expect(
        CalculatrixCommandCategory.values,
        containsAll(<CalculatrixCommandCategory>[
          CalculatrixCommandCategory.arithmetic,
          CalculatrixCommandCategory.matrix,
        ]),
      );
    });

    test('rejects two entries that share a name, at construction', () {
      expect(
        () => CalculatrixCommandRegistry(<CalculatrixCommandEntry>[
          CalculatrixCommandEntry(
            name: 'dup-name',
            category: CalculatrixCommandCategory.arithmetic,
            stackEffect: 'X -> X',
            description: 'first',
            build: () => const AddCommand(),
          ),
          CalculatrixCommandEntry(
            name: 'dup-name',
            category: CalculatrixCommandCategory.arithmetic,
            stackEffect: 'X -> X',
            description: 'second',
            build: () => const SubtractCommand(),
          ),
        ]),
        throwsArgumentError,
      );
    });

    test('rejects two entries that share an alias, case-insensitively', () {
      expect(
        () => CalculatrixCommandRegistry(<CalculatrixCommandEntry>[
          CalculatrixCommandEntry(
            name: 'first',
            aliases: const <String>['shared'],
            category: CalculatrixCommandCategory.arithmetic,
            stackEffect: 'X -> X',
            description: 'first',
            build: () => const AddCommand(),
          ),
          CalculatrixCommandEntry(
            name: 'second',
            aliases: const <String>['SHARED'],
            category: CalculatrixCommandCategory.arithmetic,
            stackEffect: 'X -> X',
            description: 'second',
            build: () => const SubtractCommand(),
          ),
        ]),
        throwsArgumentError,
      );
    });

    test('rejects an alias that collides with another entry\'s name', () {
      expect(
        () => CalculatrixCommandRegistry(<CalculatrixCommandEntry>[
          CalculatrixCommandEntry(
            name: 'taken',
            category: CalculatrixCommandCategory.arithmetic,
            stackEffect: 'X -> X',
            description: 'first',
            build: () => const AddCommand(),
          ),
          CalculatrixCommandEntry(
            name: 'other',
            aliases: const <String>['taken'],
            category: CalculatrixCommandCategory.arithmetic,
            stackEffect: 'X -> X',
            description: 'second',
            build: () => const SubtractCommand(),
          ),
        ]),
        throwsArgumentError,
      );
    });

    test('registers one entry per current operator, named per D41', () {
      const Map<String, String> nameByAlias = <String, String>{
        '+': 'add',
        '-': 'subtract',
        '*': 'multiply',
        '/': 'divide',
        '%': 'percent',
        '√': 'sqrt',
      };
      nameByAlias.forEach((String alias, String name) {
        final CalculatrixCommandEntry? byName = CalculatrixCommandRegistry
            .standard
            .lookup(name);
        final CalculatrixCommandEntry? byAlias = CalculatrixCommandRegistry
            .standard
            .lookup(alias);
        expect(byName, isNotNull, reason: '$name must be registered');
        expect(byName!.name, name);
        expect(byAlias, same(byName), reason: '$alias must alias $name');
      });

      final CalculatrixCommandEntry power = CalculatrixCommandRegistry.standard
          .lookup('power')!;
      expect(power.aliases, unorderedEquals(<String>['pwr', '^']));
    });

    test('runs every registered example and compares its result (AC6)', () {
      for (final CalculatrixCommandEntry entry
          in CalculatrixCommandRegistry.standard.entries) {
        for (final CalculatrixCommandExample example in entry.examples) {
          final List<String> tokens = Calculatrix.tokenizeRpnLine(
            example.program,
          );
          final List<Matrix> result = Calculatrix.evaluateRpnStack(tokens);
          expect(
            result,
            orderedEquals(example.expectedStack),
            reason:
                'Example "${example.program}" of "${entry.name}" did not '
                'match its documented result.',
          );
        }
      }
    });

    test('every seeAlso of every entry resolves to a registered entry', () {
      for (final CalculatrixCommandEntry entry
          in CalculatrixCommandRegistry.standard.entries) {
        for (final String related in entry.seeAlso) {
          expect(
            CalculatrixCommandRegistry.standard.lookup(related),
            isNotNull,
            reason:
                '"$related", from the seeAlso of "${entry.name}", must '
                'resolve to a registered entry.',
          );
        }
      }
    });
  });

  group('_compileRpnToken through the registry', () {
    test('resolves add/+ , subtract/-, multiply/*, divide// (D41)', () {
      expect(
        Calculatrix.evaluateRpn(<String>['2', '3', '+']),
        Matrix.scalar(5),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['2', '3', 'add']),
        Matrix.scalar(5),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['5', '3', '-']),
        Matrix.scalar(2),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['5', '3', 'subtract']),
        Matrix.scalar(2),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['4', '5', '*']),
        Matrix.scalar(20),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['4', '5', 'multiply']),
        Matrix.scalar(20),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['10', '4', '/']),
        Matrix.scalar(2.5),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['10', '4', 'divide']),
        Matrix.scalar(2.5),
      );
    });

    test('resolves sqrt/√ and percent/% through the registry', () {
      expect(Calculatrix.evaluateRpn(<String>['9', 'sqrt']), Matrix.scalar(3));
      expect(Calculatrix.evaluateRpn(<String>['9', 'SQRT']), Matrix.scalar(3));
      expect(Calculatrix.evaluateRpn(<String>['9', '√']), Matrix.scalar(3));
      expect(Calculatrix.evaluateRpn(<String>['50', '%']), Matrix.scalar(0.5));
      expect(
        Calculatrix.evaluateRpn(<String>['50', 'percent']),
        Matrix.scalar(0.5),
      );
    });

    test('power, pwr and ^ all give 8 for 2 3 (AC3)', () {
      expect(
        Calculatrix.evaluateRpn(<String>['2', '3', 'pwr']),
        Matrix.scalar(8),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['2', '3', 'POWER']),
        Matrix.scalar(8),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['2', '3', '^']),
        Matrix.scalar(8),
      );
    });

    test('a word not in the registry still raises unknown-word (AC2)', () {
      expect(
        () => Calculatrix.evaluateRpn(<String>['bogus']),
        throwsA(
          isA<UnknownWordError>().having(
            (UnknownWordError error) => error.errorId,
            'errorId',
            CalculatrixErrorId.unknownWord,
          ),
        ),
      );
    });

    test('an HP 50g-only spelling is unknown-word, never a word (D42)', () {
      expect(
        () => Calculatrix.evaluateRpn(<String>['1', '2', '2', '->ARRY']),
        throwsA(isA<UnknownWordError>()),
      );
    });

    test(
      'infix evaluation is unchanged: ^ still compiles through the registry',
      () {
        expect(Calculatrix.evaluateInfix('2^3'), Matrix.scalar(8));
      },
    );
  });
}
