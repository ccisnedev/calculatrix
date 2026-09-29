/// Command-line interface for Calculatrix, built on `modular_cli_sdk`.
library;

export 'src/cli_builder.dart' show buildCalculatrixCli;
export 'src/doctor/binary_on_path_check.dart' show PathLookup;
export 'src/stdin_reader.dart' show StdinReader, readAllStdin;
