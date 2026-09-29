import 'dart:convert';
import 'dart:io' as io;

/// Reads a full program from a source and returns it as a string.
///
/// Kept as an injectable function, rather than every caller reaching for
/// `dart:io`'s global `stdin` directly, so a test can supply a fake source
/// without faking the process's real standard input (which `dart:io` does
/// not offer a clean seam for).
typedef StdinReader = String Function();

/// The production [StdinReader]: reads every byte of the process's real
/// standard input, until it closes, and decodes it as UTF-8.
String readAllStdin() {
  final bytes = <int>[];
  int byte;
  while ((byte = io.stdin.readByteSync()) != -1) {
    bytes.add(byte);
  }
  return utf8.decode(bytes);
}
