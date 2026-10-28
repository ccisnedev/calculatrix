// Search is case-insensitive and reads "->" and "→" as the same arrow, in
// the query and in the stored text.

import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

List<String> _names(String text) => CalculatrixCommandRegistry.standard
    .search(text)
    .map((CalculatrixCommandEntry entry) => entry.name)
    .toList();

void main() {
  test('"->arry" finds the entry whose HP reference is →ARRY', () {
    final String name = CalculatrixCommandRegistry.standard.entries
        .firstWhere((CalculatrixCommandEntry e) => e.hp50gReference == '→ARRY')
        .name;
    expect(_names('->arry'), contains(name));
    expect(_names('→ARRY'), contains(name));
    expect(_names('->ARRY'), contains(name));
  });

  test('"row->" finds the entry whose HP reference is ROW→', () {
    final String name = CalculatrixCommandRegistry.standard.entries
        .firstWhere((CalculatrixCommandEntry e) => e.hp50gReference == 'ROW→')
        .name;
    expect(_names('row->'), contains(name));
  });

  test('matches name, alias, search term and description', () {
    expect(_names('POWER'), contains('power'));
    expect(_names('pwr'), contains('power'));
    expect(_names('square-root'), contains('sqrt'));
    expect(_names('eigenvector matrix'), contains('diagonalize'));
  });

  test('a text that names nothing finds nothing', () {
    expect(_names('zzzz-nothing'), isEmpty);
  });
}
