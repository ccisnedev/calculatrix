import 'dart:convert';
import 'dart:io';

/// An [IOSink] that keeps everything written to it in memory, so a test can
/// assert on exactly what a CLI run wrote to "stdout" or "stderr" without
/// touching the real process streams. Same shape as `modular_cli_sdk`'s own
/// `_MemorySink` (its `test/integration_test.dart`), kept in sync
/// deliberately: this is the pattern the SDK itself tests against.
class MemorySink implements IOSink {
  final StringBuffer _buffer = StringBuffer();

  String get output => _buffer.toString();

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  void writeln([Object? object = '']) {
    _buffer.write(object);
    _buffer.write('\n');
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) =>
      _buffer.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _buffer.writeCharCode(charCode);

  @override
  void add(List<int> data) => _buffer.write(utf8.decode(data));

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future flush() async {}

  @override
  Future close() async {}

  @override
  Future get done => Future.value();

  @override
  Encoding encoding = utf8;
}
