import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('calculatrix_cli', () {
    test('prints usage and exits successfully for --help', () async {
      final ProcessResult help = await Process.run(
        Platform.resolvedExecutable,
        <String>['run', 'bin/calculatrix_cli.dart', '--help'],
        workingDirectory: Directory.current.path,
      );

      expect(help.exitCode, 0);
      expect(help.stdout.toString(), contains('calculatrix_cli usage:'));
      expect(help.stdout.toString(), contains('command 3 4 add'));
      expect(help.stdout.toString(), contains('macro append-zero-row'));
    });

    test('keeps matrix literal parity between infix and rpn modes', () async {
      final ProcessResult infix = await Process.run(
        Platform.resolvedExecutable,
        <String>['run', 'bin/calculatrix_cli.dart', 'infix', '[[1,2],[3,4]]'],
        workingDirectory: Directory.current.path,
      );

      final ProcessResult rpn = await Process.run(
        Platform.resolvedExecutable,
        <String>['run', 'bin/calculatrix_cli.dart', 'rpn', '[[1,2],[3,4]]'],
        workingDirectory: Directory.current.path,
      );

      expect(infix.exitCode, 0);
      expect(rpn.exitCode, 0);
      expect(infix.stdout.toString().trim(), '[[1, 2], [3, 4]]');
      expect(rpn.stdout.toString().trim(), infix.stdout.toString().trim());
    });

    test('prints computed non-scalar matrices with the compact shared format', () async {
      final ProcessResult infix = await Process.run(
        Platform.resolvedExecutable,
        <String>['run', 'bin/calculatrix_cli.dart', 'infix', '[[1,0],[0,1]] * [[3,4],[5,6]]'],
        workingDirectory: Directory.current.path,
      );

      expect(infix.exitCode, 0);
      expect(infix.stdout.toString().trim(), '[[3, 4], [5, 6]]');
    });

    test('supports matrix multiplied by scalar 1x1 in infix and rpn modes', () async {
      final ProcessResult infix = await Process.run(
        Platform.resolvedExecutable,
        <String>['run', 'bin/calculatrix_cli.dart', 'infix', '[[1,0],[0,1]] * 3'],
        workingDirectory: Directory.current.path,
      );

      final ProcessResult rpn = await Process.run(
        Platform.resolvedExecutable,
        <String>['run', 'bin/calculatrix_cli.dart', 'rpn', '[[1,0],[0,1]]', '3', '*'],
        workingDirectory: Directory.current.path,
      );

      expect(infix.exitCode, 0);
      expect(rpn.exitCode, 0);
      expect(infix.stdout.toString().trim(), '[[3, 0], [0, 3]]');
      expect(rpn.stdout.toString().trim(), infix.stdout.toString().trim());
    });

    test('supports primitive command workflows through public command routing', () async {
      final ProcessResult command = await Process.run(
        Platform.resolvedExecutable,
        <String>['run', 'bin/calculatrix_cli.dart', 'command', '3', '4', 'add'],
        workingDirectory: Directory.current.path,
      );

      expect(command.exitCode, 0);
      expect(command.stdout.toString().trim(), '[[7]]');
    });

    test('supports determinant through public command routing', () async {
      final ProcessResult command = await Process.run(
        Platform.resolvedExecutable,
        <String>[
          'run',
          'bin/calculatrix_cli.dart',
          'command',
          '[[4,7],[2,6]]',
          'det',
        ],
        workingDirectory: Directory.current.path,
      );

      expect(command.exitCode, 0);
      expect(command.stdout.toString().trim(), '[[10]]');
    });

    test('supports eigenvalues through public command routing', () async {
      final ProcessResult command = await Process.run(
        Platform.resolvedExecutable,
        <String>[
          'run',
          'bin/calculatrix_cli.dart',
          'command',
          '[[2,0],[0,3]]',
          'eig',
        ],
        workingDirectory: Directory.current.path,
      );

      expect(command.exitCode, 0);
      expect(command.stdout.toString().trim(), '[[3], [2]]');
    });

    test('supports LU decomposition through public command routing', () async {
      final ProcessResult command = await Process.run(
        Platform.resolvedExecutable,
        <String>[
          'run',
          'bin/calculatrix_cli.dart',
          'command',
          '[[2,1,1],[4,-6,0],[-2,7,2]]',
          'lu',
        ],
        workingDirectory: Directory.current.path,
      );

      expect(command.exitCode, 0);
      expect(command.stdout.toString(), contains('X0: [[4, -6, 0], [0, 4, 1], [0, 0, 1]]'));
      expect(command.stdout.toString(), contains('X1: [[1, 0, 0], [0.5, 1, 0], [-0.5, 1, 1]]'));
      expect(command.stdout.toString(), contains('X2: [[0, 1, 0], [1, 0, 0], [0, 0, 1]]'));
    });

    test('supports QR decomposition through public command routing', () async {
      final ProcessResult command = await Process.run(
        Platform.resolvedExecutable,
        <String>[
          'run',
          'bin/calculatrix_cli.dart',
          'command',
          '[[1,0],[0,2],[0,0]]',
          'qr',
        ],
        workingDirectory: Directory.current.path,
      );

      expect(command.exitCode, 0);
      expect(command.stdout.toString(), contains('X0: [[1, 0], [0, 2]]'));
      expect(command.stdout.toString(), contains('X1: [[1, 0], [0, 1], [0, 0]]'));
    });

    test('supports public macro workflows', () async {
      final ProcessResult macro = await Process.run(
        Platform.resolvedExecutable,
        <String>[
          'run',
          'bin/calculatrix_cli.dart',
          'macro',
          'append-zero-row',
          '[[1,2],[3,4]]',
        ],
        workingDirectory: Directory.current.path,
      );

      expect(macro.exitCode, 0);
      expect(macro.stdout.toString().trim(), '[[1, 2], [3, 4], [0, 0]]');
    });

    test('returns non-zero for unknown commands and prints usage', () async {
      final ProcessResult invalid = await Process.run(
        Platform.resolvedExecutable,
        <String>['run', 'bin/calculatrix_cli.dart', 'bogus'],
        workingDirectory: Directory.current.path,
      );

      expect(invalid.exitCode, isNonZero);
      expect(invalid.stdout.toString(), contains('Unknown command: bogus'));
      expect(invalid.stdout.toString(), contains('calculatrix_cli usage:'));
    });

    test('returns non-zero for evaluation errors', () async {
      final ProcessResult invalid = await Process.run(
        Platform.resolvedExecutable,
        <String>['run', 'bin/calculatrix_cli.dart', 'rpn', '1', '0', '/'],
        workingDirectory: Directory.current.path,
      );

      expect(invalid.exitCode, isNonZero);
      expect(
        invalid.stdout.toString(),
        contains('Division by zero scalar is undefined'),
      );
    });
  });
}