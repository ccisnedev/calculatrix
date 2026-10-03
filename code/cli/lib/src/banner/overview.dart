/// The overview of what `cx` does (issue #72, runbook-agent-usability.md
/// D63), defined once. The banner, the install scripts and, once
/// `modular_cli_sdk` 0.10.0 is out, the help epilog (issue #56) show these
/// lines, so they cannot say different things.
///
/// RPN, infix, matrices and exact/approximate values have equal weight. The
/// symbolic form is not mentioned until it exists. ASCII only: the install
/// scripts print them in any console.
///
/// `test/banner/overview_test.dart` runs every example in them and checks
/// that both install scripts carry them verbatim.
library;

const List<String> cxOverviewLines = <String>[
  "RPN:      cx '2 3 +'   (one quoted program; it can leave several results: cx '2 sqrt 1 3 /')",
  "Infix:    cx eval infix '2+3'",
  'Values:   every value is a matrix, exact (1/3, 0.1) or approximate, marked ~ (~1.41421356237)',
  'Discover: cx commands search <term>, cx commands show <word>; add --json for JSON output',
];
