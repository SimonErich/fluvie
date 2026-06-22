/// Statically validate Fluvie composition code without executing it.
///
/// `FluvieCodeAnalyzer` resolves a snippet against `package:fluvie` and reports
/// compiler diagnostics plus the `fluvie_lints` rules as `FluvieDiagnostic`s.
/// It analyzes only: it never compiles to an executable or runs the code.
library;

export 'src/fluvie_code_analyzer.dart';
export 'src/fluvie_diagnostic.dart';
