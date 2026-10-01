import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('CalculatrixCommandRegistry.suggest (issue #41, spec section 7)', () {
    test('a typo one edit away from a name suggests that name', () {
      expect(
        CalculatrixCommandRegistry.standard.suggest('append-col'),
        contains('append-cols'),
      );
      expect(
        CalculatrixCommandRegistry.standard.suggest('inverce'),
        contains('inverse'),
      );
    });

    test('an exact match on a search term suggests its entry, even though '
        'the search term is never an edit-distance neighbor of the name', () {
      expect(
        CalculatrixCommandRegistry.standard.suggest('hcat'),
        contains('append-cols'),
      );
    });

    test('an exact search-term match is ranked ahead of a distance match', () {
      final List<String> suggestions = CalculatrixCommandRegistry.standard
          .suggest('hcat');

      expect(suggestions.first, 'append-cols');
    });

    test('a word with no close candidate suggests nothing', () {
      expect(
        CalculatrixCommandRegistry.standard.suggest(
          'zzzzzzzzzzzzzzzzzzzzzzzzzz',
        ),
        isEmpty,
      );
    });

    test('a word already in the registry has nothing to suggest', () {
      expect(CalculatrixCommandRegistry.standard.suggest('power'), isEmpty);
      expect(CalculatrixCommandRegistry.standard.suggest('PWR'), isEmpty);
    });

    test('never suggests more than the requested limit', () {
      final List<String> suggestions = CalculatrixCommandRegistry.standard
          .suggest('a', maxDistance: 5, limit: 2);

      expect(suggestions.length, lessThanOrEqualTo(2));
    });

    test('a single-character word suggests nothing: every symbolic alias '
        '(+, -, *, /) is only one edit away, which would otherwise swamp '
        'it with unrelated words', () {
      expect(CalculatrixCommandRegistry.standard.suggest('e'), isEmpty);
    });

    test('a short but multi-character typo still suggests its target', () {
      expect(
        CalculatrixCommandRegistry.standard.suggest('pow'),
        contains('power'),
      );
    });

    test('a longer typo still suggests its target', () {
      expect(
        CalculatrixCommandRegistry.standard.suggest('dupp'),
        contains('duplicate'),
      );
    });

    test('a longer typo on a hyphenated name still suggests its target', () {
      expect(
        CalculatrixCommandRegistry.standard.suggest('transpos'),
        contains('transpose'),
      );
    });

    // "pow" used to also suggest "rows" and "rotate" (via its alias "rot"),
    // both exactly as far from "pow" by raw edit distance as "power" is,
    // but sharing almost none of its letters. Tightening to the closest
    // tier, then to a prefix match within it when one exists, narrows this
    // to "power" alone (issue #51, AC6).
    test('a typo this close to its target names only that target, not '
        'other words that happen to share the same raw edit distance', () {
      expect(CalculatrixCommandRegistry.standard.suggest('pow'), [
        'power',
      ]);
    });

    // "dupp" used to also suggest "drop", one edit further from "dupp"
    // than "duplicate" (via its alias "dup") already is. Tightening to
    // the closest tier alone removes it, with no need for the prefix
    // tie-break (issue #51, AC6).
    test('a typo one tier closer to its target drops a same-maxDistance '
        'word from a different tier entirely', () {
      expect(CalculatrixCommandRegistry.standard.suggest('dupp'), [
        'duplicate',
      ]);
    });
  });

  group('UnknownWordError carries suggestions (issue #41)', () {
    test('append-col fails with unknown-word, suggesting append-cols', () {
      expect(
        () => Calculatrix.evaluateRpn(<String>[
          '0',
          '1',
          '2',
          'vector',
          '-1',
          '0',
          '2',
          'vector',
          'append-col',
        ]),
        throwsA(
          isA<UnknownWordError>()
              .having(
                (UnknownWordError e) => e.errorId,
                'errorId',
                CalculatrixErrorId.unknownWord,
              )
              .having(
                (UnknownWordError e) => e.suggestions,
                'suggestions',
                contains('append-cols'),
              )
              .having(
                (UnknownWordError e) => e.message,
                'message',
                contains('append-cols'),
              ),
        ),
      );
    });

    test('hcat (a search term, never a word) fails with unknown-word, '
        'suggesting append-cols', () {
      expect(
        () => Calculatrix.evaluateRpn(<String>['hcat']),
        throwsA(
          isA<UnknownWordError>().having(
            (UnknownWordError e) => e.suggestions,
            'suggestions',
            contains('append-cols'),
          ),
        ),
      );
    });

    test('a word with no close candidate has no suggestions at all', () {
      expect(
        () => Calculatrix.evaluateRpn(<String>['zzzzzzzzzzzzzzzzzzzzzzzzzz']),
        throwsA(
          isA<UnknownWordError>().having(
            (UnknownWordError e) => e.suggestions,
            'suggestions',
            isEmpty,
          ),
        ),
      );
    });
  });
}
