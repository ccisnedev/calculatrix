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
