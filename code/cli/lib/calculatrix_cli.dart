/// Command-line interface for Calculatrix, built on `modular_cli_sdk`.
library;

export 'src/banner/banner_query.dart'
    show BannerInput, BannerOutput, BannerQuery;
export 'src/cli_builder.dart' show buildCalculatrixCli;
export 'src/stdin_reader.dart' show StdinReader, readAllStdin;
