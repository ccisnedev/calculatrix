import 'dart:convert';
import 'dart:io';

/// An [IOSink] that keeps everything written to it in memory instead of
/// sending it anywhere, so a caller can inspect, and possibly rewrite,
/// text a lower layer already finished writing before any of it reaches a
/// real stream.
///
/// `runCalculatrixCli` is the one production caller: `modular_cli_sdk`
/// writes its `extra-argument` error for the bare `<program>` shortcut
/// (spec section 4, G4) in one call, with no seam to change its wording
/// before that write happens, so this buffers it instead and only then
/// writes the (possibly rewritten) text to the real stream. Same shape as
/// `test/support/memory_sink.dart`'s `MemorySink`, deliberately: this is
/// that same, already-proven pattern, kept production-side because test
/// code can never be imported from `lib/`.
class BufferingSink implements IOSink {
  final StringBuffer _buffer = StringBuffer();

  /// Everything written so far, as plain text.
  String get text => _buffer.toString();

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
