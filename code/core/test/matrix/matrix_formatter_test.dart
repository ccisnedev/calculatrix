import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('MatrixDisplayFormatter', () {
    final Matrix matrix = Matrix(<List<double>>[
      <double>[1, 2],
      <double>[30, 400],
    ]);

    test('renders compact one-line matrix output', () {
      expect(
        MatrixDisplayFormatter.compact(matrix),
        '[[1, 2], [30, 400]]',
      );
    });

    test('renders expanded aligned matrix output', () {
      expect(
        MatrixDisplayFormatter.expanded(matrix),
        '[ 1   2]\n[30 400]',
      );
    });
  });
}