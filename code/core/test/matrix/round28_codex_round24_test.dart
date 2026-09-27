// Core PR #7 Codex round 24, closing an incidental crash flagged (but
// explicitly not fixed) during round 23: [Matrix._exactRealEigen2x2] and its
// direct helper [Matrix._scaledCenteredDiscriminant] each compute a
// power-of-two scale exponent as `(math.log(maxAbs) / math.ln2).round()`
// (or, in the balance step, `.roundToDouble()`) without first checking that
// `maxAbs` (or the balance step's own `kBalance`) is finite. `double.round()`
// has no representation for `Infinity`/`NaN` as an [int] and throws Dart's
// own uncaught `Unsupported operation: Infinity or NaN toInt` instead of
// this package's typed, fail-closed `MatrixDomainError`.
//
// Root cause of the flagged fixture (`a = double.maxFinite`, `b = 1e300`,
// `c = -1e300`, `d = -double.maxFinite`): [Matrix._scaledCenteredDiscriminant]
// tunes its own scale to `maxAbs = max(|halfDiffHi|, |b|, |c|)`, where
// `halfDiffHi` is half of [Matrix._twoSum](a, -d)'s own high part. `a` and
// `-d` here share the same huge sign (`-d = double.maxFinite` too), so
// `a - d` overflows to `Infinity` even though `a` and `d` are each
// individually finite doubles; no per-entry finiteness check upstream of
// this scale computation ever catches that. `(math.log(Infinity) /
// math.ln2).round()` then throws.
//
// Reachability (per the coordinator's explicit "if reachable" phrasing):
// this fixture is NOT reachable through any current public API entry point.
// Every public matrix-function path that can reach _exactRealEigen2x2
// (`exp`, `log`, `power`) first calls `_requireEntriesInPrecisionRange` or
// `_requireSpectrumInPrecisionRange`, which reject any entry of magnitude
// above the declared `matrixFunctionMaxMagnitude = 1e150` outright;
// `double.maxFinite ~= 1.8e308` is rejected there, long before
// _exactRealEigen2x2 is ever called. The crash is reachable only through the
// `@visibleForTesting` debug seam `debugExactRealEigen2x2`. This is recorded
// honestly below (a pinned test on the public-API path, showing it is
// rejected by the earlier, unrelated entry-magnitude gate, not by any guard
// this round adds) rather than glossed over.
//
// Fixed by adding a finiteness guard at every scale-exponent computation in
// _exactRealEigen2x2 and _scaledCenteredDiscriminant that this round's audit
// found unguarded: the balance step's own `kBalance` (`nonFiniteBalanceScale`,
// checked before `roundToDouble()` is used, since a non-finite exponent
// would not itself throw there but would either infinite-loop or silently
// corrupt [Matrix._scalarScaleByPowerOfTwo]'s bounded-step loop downstream),
// the whole-block scale's `maxAbs` (`nonFiniteBlockScale`), and the
// discriminant's own `maxAbs` (`nonFiniteDiscriminantScale`, the original
// crash site). Each guard fails closed via the same
// `_failEigen2x2Certification(guard)` path every other guard in this file
// uses.
//
// A note on the `nonFiniteBalanceScale` fixture (`a=1, b=Infinity, c=1,
// d=1`): on the pre-fix code this does not crash immediately the way the
// original flagged fixture does. `kBalance` becomes `-Infinity`, and
// `roundToDouble()` does not itself throw on that; the non-finite exponent
// is instead handed to [Matrix._scalarScaleByPowerOfTwo], whose bounded-step
// `while (remaining.abs() > maxStep)` loop never terminates for an infinite
// `remaining` (`Infinity - 1000 == Infinity`), so the pre-fix code actually
// hangs forever on this fixture rather than throwing. Verified directly
// against the pre-fix code (timed out after 8 seconds with no output).
// Because this is a genuinely synchronous, non-yielding loop, no
// `Future.timeout`/`test`-level `Timeout` can preempt it (the event loop
// never gets a turn), so, following the same isolate-and-kill pattern
// already established in round4_correction_test.dart for exactly this
// failure mode, that one test below runs the call in a spawned [Isolate]
// and kills it if it does not report back within a bounded time.
//
// Every `.round()`/`.toInt()`/`.roundToDouble()` call site on a computed
// double in matrix.dart is audited in the round's report (not reproduced
// here); the two other sites reachable only from the unrelated
// [Matrix._eigenvalues2x2]/[Matrix._normalizedByPowerOfTwo]/
// [Matrix._powerByScalarExponent]/[Matrix._cosPi]/[Matrix._sinPi] paths are
// each either already guarded or out of scope (never reachable from
// _exactRealEigen2x2), and are left unmodified this round.
import 'dart:async';
import 'dart:isolate';

import 'package:calculatrix/calculatrix.dart';
import 'package:calculatrix/src/matrix/matrix.dart' show debugExactRealEigen2x2;
import 'package:test/test.dart';

Matcher throwsOutOfPrecisionRangeGuard(String guard) => throwsA(
  isA<MatrixDomainError>()
      .having(
        (MatrixDomainError e) => e.errorId,
        'errorId',
        CalculatrixErrorId.matrixOutOfPrecisionRange,
      )
      .having(
        (MatrixDomainError e) => e.message,
        'message',
        contains('guard: $guard'),
      ),
);

void _runNonFiniteBalanceScale(SendPort sendPort) {
  try {
    final Object? result = debugExactRealEigen2x2(1, double.infinity, 1, 1);
    sendPort.send('no-throw: $result');
  } on MatrixDomainError catch (e) {
    sendPort.send('${e.errorId?.id ?? 'null-error-id'}|${e.message}');
  } catch (e) {
    sendPort.send('unexpected: $e');
  }
}

void main() {
  group('Codex round 24 (non-finite scale exponent, P6/round23 follow-up)', () {
    test(
      'debugExactRealEigen2x2 raises matrix-out-of-precision-range (guard: '
      'nonFiniteDiscriminantScale) for a=double.maxFinite, b=1e300, '
      'c=-1e300, d=-double.maxFinite, instead of throwing the uncaught '
      '"Unsupported operation: Infinity or NaN toInt"',
      () {
        final double m = 1.7976931348623157e308;
        expect(
          () => debugExactRealEigen2x2(m, 1e300, -1e300, -m),
          throwsOutOfPrecisionRangeGuard('nonFiniteDiscriminantScale'),
        );
      },
    );

    test(
      'debugExactRealEigen2x2 raises matrix-out-of-precision-range (guard: '
      'nonFiniteBlockScale) for a=Infinity, b=1, c=1, d=1, instead of '
      'throwing the uncaught "Unsupported operation: Infinity or NaN toInt"',
      () {
        expect(
          () => debugExactRealEigen2x2(double.infinity, 1, 1, 1),
          throwsOutOfPrecisionRangeGuard('nonFiniteBlockScale'),
        );
      },
    );

    test(
      'debugExactRealEigen2x2 raises matrix-out-of-precision-range (guard: '
      'nonFiniteBalanceScale) for a=1, b=Infinity, c=1, d=1, instead of '
      'hanging forever (isolate-guarded: the pre-fix code does not crash '
      'here, it loops forever in _scalarScaleByPowerOfTwo on a non-finite '
      'exponent, verified directly against the pre-fix code)',
      () async {
        final ReceivePort port = ReceivePort();
        final Isolate isolate = await Isolate.spawn(
          _runNonFiniteBalanceScale,
          port.sendPort,
        );
        String outcome;
        try {
          outcome = await port.first.timeout(
            const Duration(seconds: 10),
          ) as String;
        } on TimeoutException {
          outcome = 'TIMED OUT (regression: this hung again)';
        } finally {
          isolate.kill(priority: Isolate.immediate);
          port.close();
        }

        expect(
          outcome,
          '${CalculatrixErrorId.matrixOutOfPrecisionRange.id}|'
          'Cannot certify the eigenvalues of this 2x2 block in double '
          'precision (guard: nonFiniteBalanceScale).',
        );
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    test(
      'reachability check (honest finding): the original flagged fixture '
      '(a=double.maxFinite, b=1e300, c=-1e300, d=-double.maxFinite) is NOT '
      'reachable through the public API today. Matrix.exp() on this input '
      'is rejected outright by the declared entry-magnitude precision '
      'range (matrixFunctionMaxMagnitude=1e150), long before '
      '_exactRealEigen2x2 (and this round\'s new guards) is ever reached; '
      'this pins that earlier, unrelated rejection so a future change that '
      'accidentally makes the fixture reachable through this path is '
      'caught here',
      () {
        final double m = 1.7976931348623157e308;
        final Matrix input = Matrix(<List<double>>[
          <double>[m, 1e300],
          <double>[-1e300, -m],
        ]);

        expect(
          input.exp,
          throwsA(
            isA<MatrixDomainError>()
                .having(
                  (MatrixDomainError e) => e.errorId,
                  'errorId',
                  CalculatrixErrorId.matrixOutOfPrecisionRange,
                )
                .having(
                  (MatrixDomainError e) => e.message,
                  'message',
                  contains('outside the declared precision range'),
                ),
          ),
        );
      },
    );
  });
}
