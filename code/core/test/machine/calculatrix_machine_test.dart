import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';

void main() {
  group('CalculatrixMachine', () {
    test('executes a typed scalar addition program equivalent to RPN engine', () {
      final CalculatrixMachine machine = CalculatrixMachine();
      final RpnEngine engine = RpnEngine();
      final CalculatrixProgram program = CalculatrixProgram(<CalculatrixCommand>[
        const PushScalarCommand(2),
        const PushScalarCommand(3),
        const AddCommand(),
      ]);

      machine.executeProgram(program);

      engine.pushScalar(2);
      engine.pushScalar(3);
      final Matrix expected = engine.applyBinary(RpnBinaryOperator.add);

      expect(machine.depth, 1);
      expect(machine.top, expected);
      expect(machine.stackSnapshot, orderedEquals(<Matrix>[expected]));
    });

    test('executeAll applies commands sequentially', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.executeAll(<CalculatrixCommand>[
        const PushScalarCommand(9),
        const PushScalarCommand(4),
        const AddCommand(),
      ]);

      expect(machine.top, Matrix.scalar(13));
      expect(machine.stackSnapshot, orderedEquals(<Matrix>[Matrix.scalar(13)]));
    });

    test('returns null top on an empty machine', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      expect(machine.top, isNull);
      expect(machine.depth, 0);
    });

    test('exposes stack snapshots as immutable views', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.execute(const PushScalarCommand(7));
      final List<Matrix> snapshot = machine.stackSnapshot;

      expect(snapshot, orderedEquals(<Matrix>[Matrix.scalar(7)]));
      expect(() => snapshot.add(Matrix.scalar(9)), throwsUnsupportedError);
    });

    test('duplicates and drops values through typed stack commands', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.executeAll(<CalculatrixCommand>[
        const PushScalarCommand(9),
        const DupCommand(),
        const DropCommand(),
      ]);

      expect(machine.depth, 1);
      expect(machine.top, Matrix.scalar(9));
      expect(machine.stackSnapshot, orderedEquals(<Matrix>[Matrix.scalar(9)]));
    });

    test('swaps and copies values through typed stack commands', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.executeAll(<CalculatrixCommand>[
        const PushScalarCommand(3),
        const PushScalarCommand(7),
        const SwapCommand(),
        const OverCommand(),
      ]);

      expect(
        machine.stackSnapshot,
        orderedEquals(<Matrix>[
          Matrix.scalar(7),
          Matrix.scalar(3),
          Matrix.scalar(7),
        ]),
      );
    });

    test('pick and roll preserve indexed stack semantics', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.executeAll(<CalculatrixCommand>[
        const PushScalarCommand(10),
        const PushScalarCommand(20),
        const PushScalarCommand(30),
        const PickCommand(2),
        const RollCommand(4),
      ]);

      expect(
        machine.stackSnapshot,
        orderedEquals(<Matrix>[
          Matrix.scalar(20),
          Matrix.scalar(30),
          Matrix.scalar(20),
          Matrix.scalar(10),
        ]),
      );
    });

    test('rotates top three values through a typed command', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.executeAll(<CalculatrixCommand>[
        const PushScalarCommand(1),
        const PushScalarCommand(2),
        const PushScalarCommand(3),
        const RotCommand(),
      ]);

      expect(
        machine.stackSnapshot,
        orderedEquals(<Matrix>[
          Matrix.scalar(2),
          Matrix.scalar(3),
          Matrix.scalar(1),
        ]),
      );
    });

    test('applies typed unary commands with existing engine semantics', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.executeAll(<CalculatrixCommand>[
        const PushScalarCommand(81),
        const SqrtCommand(),
        const PercentCommand(),
      ]);

      expect(machine.top, Matrix.scalar(0.09));
    });

    test('applies typed binary commands with existing engine semantics', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.executeAll(<CalculatrixCommand>[
        const PushScalarCommand(10),
        const PushScalarCommand(4),
        const SubtractCommand(),
        const PushScalarCommand(3),
        const MultiplyCommand(),
        const PushScalarCommand(2),
        const DivideCommand(),
      ]);

      expect(machine.top, Matrix.scalar(9));
      expect(machine.depth, 1);
    });

    test('surfaces stack range errors through typed commands', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.execute(const PushScalarCommand(1));

      expect(() => machine.execute(const PickCommand(0)), throwsA(isA<RpnStackRangeError>()));
      expect(() => machine.execute(const RollCommand(2)), throwsA(isA<RpnStackRangeError>()));
    });

    test('pushes zeros, ones, and identity matrices through typed commands', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.executeAll(<CalculatrixCommand>[
        const PushZerosCommand(2, 2),
        const PushOnesCommand(2, 2),
        const PushIdentityCommand(2),
      ]);

      expect(
        machine.stackSnapshot,
        orderedEquals(<Matrix>[
          Matrix.zeros(2, 2),
          Matrix.ones(2, 2),
          Matrix.identity(2),
        ]),
      );
    });

    test('applies negate and transpose through typed matrix commands', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.executeAll(<CalculatrixCommand>[
        PushMatrixCommand(
          Matrix(<List<double>>[
            <double>[1, -2, 3],
            <double>[4, -5, 6],
          ]),
        ),
        const NegateCommand(),
        const TransposeCommand(),
      ]);

      expect(
        machine.top,
        Matrix(<List<double>>[
          <double>[-1, -4],
          <double>[2, 5],
          <double>[-3, -6],
        ]),
      );
    });

    test('applies inverse through a typed matrix command', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.execute(
        PushMatrixCommand(
          Matrix(<List<double>>[
            <double>[4, 7],
            <double>[2, 6],
          ]),
        ),
      );
      machine.execute(const InverseCommand());

      expect(
        machine.top!.almostEquals(
          Matrix(<List<double>>[
            <double>[0.6, -0.7],
            <double>[-0.2, 0.4],
          ]),
        ),
        isTrue,
      );
    });

    test('surfaces typed shape errors for invalid construction commands', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      expect(() => machine.execute(const PushZerosCommand(0, 2)), throwsA(isA<MatrixShapeError>()));
      expect(() => machine.execute(const PushOnesCommand(2, 0)), throwsA(isA<MatrixShapeError>()));
      expect(() => machine.execute(const PushIdentityCommand(0)), throwsA(isA<MatrixShapeError>()));
    });

    test('appends compatible row and column operands through typed commands', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.executeAll(<CalculatrixCommand>[
        PushMatrixCommand(
          Matrix(<List<double>>[
            <double>[1, 2],
            <double>[3, 4],
          ]),
        ),
        PushMatrixCommand(Matrix(<List<double>>[<double>[5, 6]])),
        const AppendRowCommand(),
      ]);

      expect(
        machine.top,
        Matrix(<List<double>>[
          <double>[1, 2],
          <double>[3, 4],
          <double>[5, 6],
        ]),
      );

      machine.executeAll(<CalculatrixCommand>[
        PushMatrixCommand(
          Matrix(<List<double>>[
            <double>[7],
            <double>[8],
            <double>[9],
          ]),
        ),
        const AppendColumnCommand(),
      ]);

      expect(
        machine.top,
        Matrix(<List<double>>[
          <double>[1, 2, 7],
          <double>[3, 4, 8],
          <double>[5, 6, 9],
        ]),
      );
    });

    test('applies structural row and column commands to the top matrix', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.execute(
        PushMatrixCommand(
          Matrix(<List<double>>[
            <double>[1, 2, 3],
            <double>[4, 5, 6],
            <double>[7, 8, 9],
          ]),
        ),
      );
      machine.execute(const DuplicateRowCommand(0));
      machine.execute(const MoveRowCommand(3, 1));
      machine.execute(const DeleteColumnCommand(2));
      machine.execute(const DuplicateColumnCommand(0));
      machine.execute(const MoveColumnCommand(2, 0));
      machine.execute(const DeleteRowCommand(2));

      expect(
        machine.top,
        Matrix(<List<double>>[
          <double>[2, 1, 1],
          <double>[8, 7, 7],
          <double>[5, 4, 4],
        ]),
      );
    });

    test('surfaces typed structural index and shape errors through commands', () {
      final CalculatrixMachine machine = CalculatrixMachine();

      machine.execute(PushMatrixCommand(Matrix(<List<double>>[<double>[1, 2]])));
      expect(() => machine.execute(const DeleteRowCommand(1)), throwsA(isA<MatrixIndexError>()));

      machine.clear();
      machine.execute(
        PushMatrixCommand(
          Matrix(<List<double>>[
            <double>[1],
            <double>[2],
          ]),
        ),
      );
      expect(() => machine.execute(const DeleteColumnCommand(0)), throwsA(isA<MatrixShapeError>()));
    });
  });
}