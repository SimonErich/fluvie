import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:custom_lint_core/custom_lint_core.dart';
import 'package:fluvie_lints/fluvie_lints.dart';
import 'package:fluvie_validate/src/fluvie_diagnostic.dart';
import 'package:path/path.dart' as p;

part 'diagnostic_suppressions.dart';

/// Resolves a Fluvie snippet against `package:fluvie` and reports its
/// diagnostics. It analyzes only: it never compiles to an executable or runs
/// the code, so calling [analyze] on arbitrary input is safe.
final class FluvieCodeAnalyzer {
  /// Creates an analyzer that writes scratch files under [projectRoot].
  ///
  /// [projectRoot] must be a directory inside a package that resolves
  /// `package:fluvie` (the workspace root, or the example app in the server
  /// image), so the snippet's imports and types resolve. [lintRules] defaults
  /// to the full Fluvie rule set; the structural rules read a `lib/` path and so
  /// stay silent on the standalone scratch file.
  FluvieCodeAnalyzer({required this.projectRoot, List<DartLintRule>? lintRules})
    : _lintRules = lintRules ?? fluvieLintRules;

  /// The directory whose package resolution the scratch file inherits.
  final Directory projectRoot;

  final List<DartLintRule> _lintRules;
  AnalysisContextCollection? _contexts;
  Future<void> _pending = Future.value();

  AnalysisContextCollection get _collection => _contexts ??= AnalysisContextCollection(
    includedPaths: [p.normalize(projectRoot.absolute.path)],
  );

  /// Frees the reusable analyzer context after the last request.
  Future<void> dispose() => _serial(() async {
    await _contexts?.dispose();
    _contexts = null;
  });

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    // Every caller receives its error; one failed request must not poison the
    // queue or invalidate another request's analyzer session.
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  /// Analyzes the original file without moving it or executing its code.
  ///
  /// Relative imports resolve from the authored directory. The same analyzer
  /// context is reused on subsequent requests and refreshed after file edits.
  Future<List<FluvieDiagnostic>> analyzeFile(String path) => _serial(() => _analyzeFile(path));

  Future<List<FluvieDiagnostic>> _analyzeFile(String path) async {
    final file = File(p.normalize(p.absolute(path)));
    if (!file.existsSync()) throw FileSystemException('No such Dart file', file.path);
    final context = _collection.contextFor(file.path)..changeFile(file.path);
    await context.applyPendingFileChanges();
    return _diagnostics(await context.currentSession.getResolvedUnit(file.path));
  }

  /// Analyzes [code] and returns its diagnostics.
  ///
  /// Compiler infos (style lints) are dropped as noise; errors and warnings, and
  /// every Fluvie lint, are kept. The snippet is written to a unique scratch file
  /// that is always deleted, even on failure.
  Future<List<FluvieDiagnostic>> analyze(String code) => _serial(() => _analyze(code));

  Future<List<FluvieDiagnostic>> _analyze(String code) async {
    final scratch = Directory('${projectRoot.path}/.fluvie_scratch')..createSync(recursive: true);
    final file = File('${scratch.path}/snippet_${DateTime.now().microsecondsSinceEpoch}_$pid.dart')
      ..writeAsStringSync(code);
    try {
      // Scratch paths are deliberately excluded from normal whole-project
      // analysis. Resolve them explicitly in their containing project context.
      final context = _collection.contexts.firstWhere(
        (context) => context.contextRoot.root.contains(file.absolute.path),
      )..changeFile(file.absolute.path);
      await context.applyPendingFileChanges();
      return await _diagnostics(await context.currentSession.getResolvedUnit(file.absolute.path));
    } finally {
      if (file.existsSync()) file.deleteSync();
    }
  }

  Future<List<FluvieDiagnostic>> _diagnostics(Object resolved) async {
    // coverage:ignore-start getResolvedUnit yields a ResolvedUnitResult for any readable
    // Dart file we just wrote, so this only guards the unreachable InvalidResult case.
    if (resolved is! ResolvedUnitResult) {
      return const [
        FluvieDiagnostic(
          severity: FluvieDiagnosticSeverity.error,
          message: 'Could not analyze the code.',
          line: 1,
          column: 1,
        ),
      ];
    }
    // coverage:ignore-end
    final suppressions = _DiagnosticSuppressions(resolved);
    final diagnostics = <FluvieDiagnostic>[];
    for (final diagnostic in resolved.diagnostics) {
      final severity = _severityFor(diagnostic.severity);
      if (severity == FluvieDiagnosticSeverity.info) continue;
      diagnostics.add(_map(diagnostic, severity, resolved));
    }
    for (final rule in _lintRules) {
      // The Playground reuses the real fluvie_lints rules to lint one snippet;
      // testRun is their analyzer-facing entry. The custom_lint_core constraint
      // and the rule-fires test guard against this visible-for-testing API
      // drifting on an upgrade.
      // ignore: invalid_use_of_visible_for_testing_member
      for (final diagnostic in await rule.testRun(resolved)) {
        if (suppressions.contains(diagnostic)) continue;
        diagnostics.add(_map(diagnostic, _severityFor(diagnostic.severity), resolved));
      }
    }
    return diagnostics;
  }

  FluvieDiagnostic _map(
    Diagnostic diagnostic,
    FluvieDiagnosticSeverity severity,
    ResolvedUnitResult resolved,
  ) {
    final start = resolved.lineInfo.getLocation(diagnostic.offset);
    return FluvieDiagnostic(
      severity: severity,
      message: diagnostic.message,
      line: start.lineNumber,
      column: start.columnNumber,
      length: diagnostic.length,
      code: diagnostic.diagnosticCode.name,
    );
  }

  static FluvieDiagnosticSeverity _severityFor(Severity severity) {
    if (severity == Severity.error) return FluvieDiagnosticSeverity.error;
    if (severity == Severity.warning) return FluvieDiagnosticSeverity.warning;
    return FluvieDiagnosticSeverity.info;
  }
}
