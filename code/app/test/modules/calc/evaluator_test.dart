import 'package:flutter_test/flutter_test.dart';
import 'package:calculatrix/modules/calc/models/evaluator.dart';
import 'package:calculatrix/modules/calc/models/parser.dart';
import 'package:calculatrix/modules/calc/models/tokenizer.dart';

void main() {
  late Tokenizer tokenizer;
  late Parser parser;
  late Evaluator evaluator;

  setUp(() {
    tokenizer = Tokenizer();
    parser = Parser();
    evaluator = Evaluator();
  });

  /// Helper: evaluate a string expression end-to-end.
  double eval(String input) {
    final tokens = tokenizer.tokenize(input);
    final ast = parser.parse(tokens);
    return evaluator.evaluate(ast);
  }

  group('Evaluator - basic arithmetic', () {
    test('addition: 3+4 = 7', () => expect(eval('3+4'), 7.0));
    test('subtraction: 10-3 = 7', () => expect(eval('10-3'), 7.0));
    test('multiplication: 5×6 = 30', () => expect(eval('5×6'), 30.0));
    test('division: 8÷2 = 4', () => expect(eval('8÷2'), 4.0));
  });

  group('Evaluator - precedence', () {
    test('3+4×5 = 23', () => expect(eval('3+4×5'), 23.0));
    test('10-8÷2 = 6', () => expect(eval('10-8÷2'), 6.0));
    test('2+3×4-1 = 13', () => expect(eval('2+3×4-1'), 13.0));
    test('2×3+4×5 = 26', () => expect(eval('2×3+4×5'), 26.0));
  });

  group('Evaluator - parentheses', () {
    test('(3+4)×5 = 35', () => expect(eval('(3+4)×5'), 35.0));
    test('(10-8)÷2 = 1', () => expect(eval('(10-8)÷2'), 1.0));
    test('((2+3))×4 = 20', () => expect(eval('((2+3))×4'), 20.0));
    test('(1+2)×(3+4) = 21', () => expect(eval('(1+2)×(3+4)'), 21.0));
  });

  group('Evaluator - unary negation', () {
    test('-5 = -5', () => expect(eval('-5'), -5.0));
    test('-5+3 = -2', () => expect(eval('-5+3'), -2.0));
    test('3×-2 = -6', () => expect(eval('3×-2'), -6.0));
    test('(-3+4) = 1', () => expect(eval('(-3+4)'), 1.0));
    test('-(3+4) = -7', () => expect(eval('-(3+4)'), -7.0));
  });

  group('Evaluator - decimals', () {
    test('3.14×2 = 6.28', () => expect(eval('3.14×2'), closeTo(6.28, 0.001)));
    test('0.1+0.2 ≈ 0.3', () => expect(eval('0.1+0.2'), closeTo(0.3, 1e-10)));
    test('1÷3 ≈ 0.333...', () => expect(eval('1÷3'), closeTo(0.3333, 0.001)));
  });

  group('Evaluator - left associativity', () {
    test('10-3-2 = 5', () => expect(eval('10-3-2'), 5.0));
    test('20÷4÷5 = 1', () => expect(eval('20÷4÷5'), 1.0));
    test('2-3+4 = 3', () => expect(eval('2-3+4'), 3.0));
  });

  group('Evaluator - division by zero', () {
    test('1÷0 = infinity', () => expect(eval('1÷0'), double.infinity));
    test('-1÷0 = -infinity', () => expect(eval('-1÷0'), double.negativeInfinity));
    test('0÷0 = NaN', () => expect(eval('0÷0'), isNaN));
  });

  group('Evaluator - complex expressions', () {
    test('(2+3)×(7-4)÷5 = 3', () => expect(eval('(2+3)×(7-4)÷5'), 3.0));
    test('100-50×2 = 0', () => expect(eval('100-50×2'), 0.0));
    test('1+2+3+4+5 = 15', () => expect(eval('1+2+3+4+5'), 15.0));
  });

  group('Evaluator - square root', () {
    test('√9 = 3', () => expect(eval('√9'), 3.0));
    test('√16 = 4', () => expect(eval('√16'), 4.0));
    test('√2 ≈ 1.414', () => expect(eval('√2'), closeTo(1.4142, 0.001)));
    test('√0 = 0', () => expect(eval('√0'), 0.0));
    test('√(4+5) = 3', () => expect(eval('√(4+5)'), 3.0));
    test('2×√4 = 4', () => expect(eval('2×√4'), 4.0));
    test('√(-1) = NaN', () => expect(eval('√(-1)'), isNaN));
  });

  group('Evaluator - percent', () {
    test('50% = 0.5', () => expect(eval('50%'), 0.5));
    test('100% = 1', () => expect(eval('100%'), 1.0));
    test('25% = 0.25', () => expect(eval('25%'), 0.25));
    test('200+10% = 200.1', () => expect(eval('200+10%'), 200.1));
  });
}
