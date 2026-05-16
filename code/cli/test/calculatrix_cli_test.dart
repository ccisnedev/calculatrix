import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('calculatrix_cli', () {
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
  });
}