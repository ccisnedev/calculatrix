import 'package:calculatrix/calculatrix.dart';
import 'package:test/test.dart';
import 'dart:math' as math;

void main() {
  group('Matrix.exp — matrix exponential', () {
    test('exp(0) = I (identity)', () {
      final Matrix zero = Matrix.zeros(2, 2);
      expect(zero.exp(), Matrix.identity(2));
    });

    test('exp(I) = e·I (scalar exponential for diagonal)', () {
      final Matrix identity = Matrix.identity(2);
      final Matrix result = identity.exp();
      // Should be e·I ≈ [[2.718, 0], [0, 2.718]]
      final double e = math.e;
      expect(result.at(0, 0), closeTo(e, 1e-10));
      expect(result.at(0, 1), closeTo(0, 1e-10));
      expect(result.at(1, 0), closeTo(0, 1e-10));
      expect(result.at(1, 1), closeTo(e, 1e-10));
    });

    test('exp(-I) = e^(-1)·I', () {
      final Matrix negIdentity = Matrix.identity(2).scale(-1);
      final Matrix result = negIdentity.exp();
      final double invE = 1 / math.e;
      expect(result.at(0, 0), closeTo(invE, 1e-10));
      expect(result.at(1, 1), closeTo(invE, 1e-10));
    });

    test('exp(θ·J) for θ = π/2 = [[0, -1], [1, 0]] (near [[cos(π/2), -sin(π/2)], [sin(π/2), cos(π/2)]])', () {
      // exp(π/2 · i) = cos(π/2) + sin(π/2)·i = 0 + 1·i = i
      final double theta = math.pi / 2;
      final Matrix thetaJ = Matrix.i.scale(theta);
      final Matrix result = thetaJ.exp();

      // Expected: [[cos(θ), -sin(θ)], [sin(θ), cos(θ)]]
      final double c = math.cos(theta);
      final double s = math.sin(theta);

      expect(result.at(0, 0), closeTo(c, 1e-10)); // cos(π/2) ≈ 0
      expect(result.at(0, 1), closeTo(-s, 1e-10)); // -sin(π/2) ≈ -1
      expect(result.at(1, 0), closeTo(s, 1e-10)); // sin(π/2) ≈ 1
      expect(result.at(1, 1), closeTo(c, 1e-10)); // cos(π/2) ≈ 0
    });

    test('exp(0) for 3×3 = I₃', () {
      final Matrix zero = Matrix.zeros(3, 3);
      expect(zero.exp(), Matrix.identity(3));
    });
  });

  group('Euler\'s formula via matrix exponential', () {
    test('e^(πi) = -I (Euler\'s formula)', () {
      // exp(π·i) = [[cos(π), -sin(π)], [sin(π), cos(π)]] = [[-1, 0], [0, -1]] = -I
      final Matrix piJ = Matrix.i.scale(math.pi);
      final Matrix result = piJ.exp();
      final Matrix negIdentity = Matrix.identity(2).scale(-1);

      expect(result.at(0, 0), closeTo(negIdentity.at(0, 0), 1e-9));
      expect(result.at(0, 1), closeTo(negIdentity.at(0, 1), 1e-9));
      expect(result.at(1, 0), closeTo(negIdentity.at(1, 0), 1e-9));
      expect(result.at(1, 1), closeTo(negIdentity.at(1, 1), 1e-9));
    });

    test('e^(πi) + I = 0 (Euler identity)', () {
      final Matrix piJ = Matrix.i.scale(math.pi);
      final Matrix expPiI = piJ.exp();
      final Matrix identity = Matrix.identity(2);
      final Matrix result = expPiI + identity;

      // All elements should be near zero
      expect(result.at(0, 0), closeTo(0, 1e-9));
      expect(result.at(0, 1), closeTo(0, 1e-9));
      expect(result.at(1, 0), closeTo(0, 1e-9));
      expect(result.at(1, 1), closeTo(0, 1e-9));
    });

    test('e^(2πi) = I (full rotation)', () {
      final Matrix twopiJ = Matrix.i.scale(2 * math.pi);
      final Matrix result = twopiJ.exp();
      final Matrix identity = Matrix.identity(2);

      expect(result.at(0, 0), closeTo(identity.at(0, 0), 1e-8));
      expect(result.at(0, 1), closeTo(identity.at(0, 1), 1e-8));
      expect(result.at(1, 0), closeTo(identity.at(1, 0), 1e-8));
      expect(result.at(1, 1), closeTo(identity.at(1, 1), 1e-8));
    });

    test('e^(π/4·i) = (1/√2)·(1+i)', () {
      // cos(π/4) = sin(π/4) = 1/√2
      // [[1/√2, -1/√2], [1/√2, 1/√2]] = (1/√2)·(1+i) in complex form
      final double theta = math.pi / 4;
      final Matrix thetaJ = Matrix.i.scale(theta);
      final Matrix result = thetaJ.exp();

      final double c = 1 / math.sqrt(2);
      expect(result.at(0, 0), closeTo(c, 1e-10));
      expect(result.at(0, 1), closeTo(-c, 1e-10));
      expect(result.at(1, 0), closeTo(c, 1e-10));
      expect(result.at(1, 1), closeTo(c, 1e-10));
    });

    test('e^(θ₁·i) · e^(θ₂·i) = e^((θ₁+θ₂)·i) (angle addition)', () {
      final double theta1 = math.pi / 6;
      final double theta2 = math.pi / 3;

      final Matrix exp1 = Matrix.i.scale(theta1).exp();
      final Matrix exp2 = Matrix.i.scale(theta2).exp();
      final Matrix product = exp1 * exp2;

      final Matrix expSum = Matrix.i.scale(theta1 + theta2).exp();

      expect(product.at(0, 0), closeTo(expSum.at(0, 0), 1e-9));
      expect(product.at(0, 1), closeTo(expSum.at(0, 1), 1e-9));
      expect(product.at(1, 0), closeTo(expSum.at(1, 0), 1e-9));
      expect(product.at(1, 1), closeTo(expSum.at(1, 1), 1e-9));
    });
  });

  group('Complex exponential via exp(θ·i)', () {
    test('e^i displays as cos(1) + sin(1)·i', () {
      final Matrix ei = Matrix.i.exp();
      expect(ei.isComplexForm, isTrue);
      expect(ei.realPart, closeTo(math.cos(1), 1e-10));
      expect(ei.imagPart, closeTo(math.sin(1), 1e-10));
    });

    test('e^(3 + 2i) = e^3 · e^(2i) (real × complex)', () {
      // Note: requires Matrix.exp to handle non-pure-imaginary matrices
      // This is an aspirational test; actual 2×2 matrix exponential is complex
      final Matrix threeI = Matrix.identity(2).scale(3);
      final Matrix twoI = Matrix.i.scale(2);
      final Matrix sum = threeI + twoI;
      final Matrix result = sum.exp();

      // Approximate: e^3 ≈ 20.086, e^(2i) ≈ cos(2) + sin(2)·i
      final double e3 = math.exp(3);
      final double c2 = math.cos(2);
      final double s2 = math.sin(2);

      // result ≈ e^3 · [[cos(2), -sin(2)], [sin(2), cos(2)]]
      expect(result.at(0, 0), closeTo(e3 * c2, 0.01));
      expect(result.at(0, 1), closeTo(-e3 * s2, 0.01));
      expect(result.at(1, 0), closeTo(e3 * s2, 0.01));
      expect(result.at(1, 1), closeTo(e3 * c2, 0.01));
    });
  });
}
