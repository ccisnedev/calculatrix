import '../rpn/rpn_engine.dart';

abstract base class CalculatrixCommand {
  const CalculatrixCommand();

  void executeOn(RpnEngine engine);
}