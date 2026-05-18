import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('Calculatrix macros', () {
    test('fill zeros like top replaces the top matrix with same-shape zeros', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.execute(
        PushMatrixCommand(
          Matrix(<List<double>>[
            <double>[1, 2],
            <double>[3, 4],
          ]),
        ),
      );
      machine.executeMacro(const FillZerosLikeTopMacro());

      expect(machine.top, Matrix.zeros(2, 2));
    });

    test('fill ones like top replaces the top matrix with same-shape ones', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.execute(
        PushMatrixCommand(
          Matrix(<List<double>>[
            <double>[1, 2, 3],
          ]),
        ),
      );
      machine.executeMacro(const FillOnesLikeTopMacro());

      expect(machine.top, Matrix.ones(1, 3));
    });

    test('append zero row and column macros reuse public commands', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.execute(
        PushMatrixCommand(
          Matrix(<List<double>>[
            <double>[1, 2],
            <double>[3, 4],
          ]),
        ),
      );
      machine.executeMacro(const AppendZeroRowMacro());
      machine.executeMacro(const AppendZeroColumnMacro());

      expect(
        machine.top,
        Matrix(<List<double>>[
          <double>[1, 2, 0],
          <double>[3, 4, 0],
          <double>[0, 0, 0],
        ]),
      );
    });

    test('create identity macro pushes a fresh identity matrix', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.executeMacro(const CreateIdentityMacro(3));

      expect(machine.top, Matrix.identity(3));
    });

    test('shape-derived macros require a non-empty stack', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      expect(
        () => machine.executeMacro(const FillZerosLikeTopMacro()),
        throwsA(isA<RpnStackUnderflowError>()),
      );
      expect(
        () => machine.executeMacro(const AppendZeroColumnMacro()),
        throwsA(isA<RpnStackUnderflowError>()),
      );
    });
  });
}