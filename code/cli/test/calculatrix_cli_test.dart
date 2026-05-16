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
      expect(infix.stdout.toString().trim(), 'Matrix([[1.0, 2.0], [3.0, 4.0]])');
      expect(rpn.stdout.toString().trim(), infix.stdout.toString().trim());
    });
  });
}