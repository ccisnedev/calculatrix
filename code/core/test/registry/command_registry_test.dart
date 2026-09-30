import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('CalculatrixCommandRegistry.standard', () {
    test('resolves a name case-insensitively', () {
      final CalculatrixCommandEntry? entry = CalculatrixCommandRegistry.standard
          .lookup('POWER');

      expect(entry, isNotNull);
      expect(entry!.name, 'power');
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
        // "add" is a search term of "+" (spec section 7), not one of its
        // aliases: it must not resolve here, and using it as an RPN word
        // must raise unknown-word (AC4).
        final CalculatrixCommandEntry plus = CalculatrixCommandRegistry.standard
            .lookup('+')!;
        expect(plus.searchTerms, contains('add'));
        expect(CalculatrixCommandRegistry.standard.lookup('add'), isNull);

        expect(
          () => Calculatrix.evaluateRpn(<String>['2', '3', 'add']),
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
      expect(power.hp50gEquivalent, '^');
      expect(power.build(), isA<PowerCommand>());
    });

    test('categories are an enumeration', () {
      expect(
        CalculatrixCommandCategory.values,
        contains(CalculatrixCommandCategory.arithmetic),
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

    test('registers one entry per current operator, with no new math', () {
      const List<String> currentOperators = <String>[
        '+',
        '-',
        '*',
        '/',
        '√',
        '%',
      ];
      for (final String operatorToken in currentOperators) {
        final CalculatrixCommandEntry? entry = CalculatrixCommandRegistry
            .standard
            .lookup(operatorToken);
        expect(entry, isNotNull, reason: '$operatorToken must be registered');
        expect(entry!.name, operatorToken);
      }

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
          final Matrix result = Calculatrix.evaluateRpn(tokens);
          expect(
            result,
            example.expected,
            reason:
                'Example "${example.program}" of "${entry.name}" did not '
                'match its documented result.',
          );
        }
      }
    });
  });

  group('_compileRpnToken through the registry', () {
    test('resolves + - * / through the registry, not a hardcoded switch', () {
      expect(
        Calculatrix.evaluateRpn(<String>['2', '3', '+']),
        Matrix.scalar(5),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['5', '3', '-']),
        Matrix.scalar(2),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['4', '5', '*']),
        Matrix.scalar(20),
      );
      expect(
        Calculatrix.evaluateRpn(<String>['10', '4', '/']),
        Matrix.scalar(2.5),
      );
    });

    test('resolves √ and % through the registry', () {
      expect(Calculatrix.evaluateRpn(<String>['9', '√']), Matrix.scalar(3));
      expect(Calculatrix.evaluateRpn(<String>['50', '%']), Matrix.scalar(0.5));
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

    test(
      'infix evaluation is unchanged: ^ still compiles through the registry',
      () {
        expect(Calculatrix.evaluateInfix('2^3'), Matrix.scalar(8));
      },
    );
  });
}
