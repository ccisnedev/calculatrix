import 'package:calculatrix/calculatrix.dart';

void main() {
  const int iterations = 5000;
  final Stopwatch watch = Stopwatch()..start();

  for (int i = 0; i < iterations; i++) {
    Calculatrix.evaluateInfix('((1e-3 + 2) * 3) / 4 + √9');
    Calculatrix.evaluateRpn(<String>['1e-3', '2', '+', '3', '*', '4', '/', '9', '√', '+']);
  }

  watch.stop();
  print('iterations=$iterations elapsedMs=${watch.elapsedMilliseconds}');
}
