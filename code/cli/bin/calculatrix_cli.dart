import 'package:calculatrix/calculatrix.dart';

void main(List<String> args) {
  if (args.isEmpty || args.first == '--help' || args.first == '-h') {
    _printUsage();
    return;
  }

  final String mode = args.first.toLowerCase();

  try {
    switch (mode) {
      case 'infix':
        if (args.length < 2) {
          throw const FormatException('Missing infix expression.');
        }
        final String expression = args.sublist(1).join(' ');
        final Matrix infixResult = Calculatrix.evaluateInfix(expression);
        print(MatrixDisplayFormatter.compact(infixResult));
      case 'rpn':
        if (args.length < 2) {
          throw const FormatException('Missing RPN tokens.');
        }
        final List<String> rpnTokens = args.sublist(1);
        final Matrix rpnResult = Calculatrix.evaluateRpn(rpnTokens);
        print(MatrixDisplayFormatter.compact(rpnResult));
      default:
        throw FormatException('Unknown command: $mode');
    }
  } on CalculatrixError catch (error) {
    print(error);
  } on FormatException catch (error) {
    print('CLI error: ${error.message}');
    _printUsage();
  }
}

void _printUsage() {
  print('calculatrix_cli usage:');
  print('  dart run bin/calculatrix_cli.dart infix "3 + 4 * 5"');
  print('  dart run bin/calculatrix_cli.dart rpn 3 4 + 5 *');
}
