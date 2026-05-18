// ignore_for_file: avoid_print

/// Example usage of the `calculatrix` package.
///
/// Demonstrates matrix creation, algebraic operations, decompositions,
/// RPN evaluation, and interactive session usage.
import 'package:calculatrix/calculatrix.dart';

void main() {
  // ── Matrix creation ──────────────────────────────────────────────────────
  final a = Matrix([
    [1, 2],
    [3, 4],
  ]);
  final b = Matrix([
    [5, 6],
    [7, 8],
  ]);

  print('A = ${a.rows}');
  print('B = ${b.rows}');

  // ── Basic operations ─────────────────────────────────────────────────────
  print('A + B = ${(a + b).rows}');
  print('A * B = ${(a * b).rows}');
  print('det(A) = ${a.determinant().scalarValue}');
  print('trace(A) = ${a.trace().scalarValue}');
  print('rank(A) = ${a.rank().scalarValue.toInt()}');
  print('‖A‖_F = ${a.frobeniusNorm().scalarValue}');
  print('‖A‖₂ = ${a.spectralNorm().scalarValue}');

  // ── Decompositions ───────────────────────────────────────────────────────
  final lu = a.luDecomposition();
  print('LU: L = ${lu.lower.rows}, U = ${lu.upper.rows}');

  final qr = a.qrDecomposition();
  print('QR: Q = ${qr.q.rows}, R = ${qr.r.rows}');

  print('RREF(A) = ${a.rref().rows}');

  // ── Eigenvalues and diagonalization ──────────────────────────────────────
  final symmetric = Matrix([
    [4, 1],
    [1, 3],
  ]);
  final eigs = symmetric.eigenvalues();
  print('eigenvalues of [[4,1],[1,3]] = ${eigs.rows}');

  final diag = symmetric.diagonalization();
  print('P = ${diag.p.rows}');
  print('D = ${diag.d.rows}');

  // ── Vector operations ────────────────────────────────────────────────────
  final u = Matrix([
    [1],
    [2],
    [3],
  ]);
  final v = Matrix([
    [4],
    [5],
    [6],
  ]);
  print('u · v = ${u.dot(v).scalarValue}');
  print('u × v = ${u.cross(v).rows}');

  // ── Standard test matrices ───────────────────────────────────────────────
  final h3 = Matrix.hilbert(3);
  print('Hilbert(3) = ${h3.rows}');

  final p4 = Matrix.pascal(4);
  print('Pascal(4) det = ${p4.determinant().scalarValue}'); // always 1

  // ── Infix evaluation ─────────────────────────────────────────────────────
  final result = Calculatrix.evaluateInfix('2 + 3 * 4');
  print('2 + 3 * 4 = ${result.scalarValue}'); // 14

  // ── RPN evaluation ───────────────────────────────────────────────────────
  final rpnResult = Calculatrix.evaluateRpn(['3', '4', '+', '2', '*']);
  print('3 4 + 2 * = ${rpnResult.scalarValue}'); // 14

  // ── Machine (stack) usage ────────────────────────────────────────────────
  final machine = CalculatrixMachine();
  machine.execute(PushMatrixCommand(a));
  machine.execute(DeterminantCommand());
  print('Machine: det via stack = ${machine.top!.scalarValue}');

  // ── Session (interactive calculator) ─────────────────────────────────────
  final session = CalculatrixSession();
  session.input('5');
  session.input('+');
  session.input('3');
  session.evaluate(); // 5 + 3 = 8
  print('Session: 5 + 3 = ${session.currentValue!.scalarValue}');
}
