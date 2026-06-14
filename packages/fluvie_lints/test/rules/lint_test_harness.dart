import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Resolves [fixtureName] under `test/fixtures/` and runs [rule] against it,
/// returning every line number (1-based) where the rule fired.
Future<List<int>> lintLinesFor(DartLintRule rule, String fixtureName) async {
  final result = await _resolve(fixtureName);
  final diagnostics = await rule.testRun(result);
  return diagnostics.map((d) => result.lineInfo.getLocation(d.offset).lineNumber).toList()..sort();
}

/// Resolves [fixtureName] and applies [fix] to the single diagnostic [rule]
/// reports, returning the rewritten source. Asserts exactly one diagnostic.
Future<String> applyFixTo(
  DartLintRule rule,
  DartFix fix,
  String fixtureName,
) async {
  final result = await _resolve(fixtureName);
  final diagnostics = await rule.testRun(result);
  if (diagnostics.length != 1) {
    throw StateError(
      'Expected exactly one diagnostic to fix, found ${diagnostics.length}.',
    );
  }
  final changes = await fix.testRun(result, diagnostics.single, diagnostics);
  return _apply(result.content, changes);
}

Future<ResolvedUnitResult> _resolve(String fixtureName) async {
  final file = File('test/fixtures/$fixtureName');
  final result = await resolveFile(path: file.absolute.path);
  return result as ResolvedUnitResult;
}

String _apply(String source, List<PrioritizedSourceChange> changes) {
  final edits = <SourceEdit>[
    for (final change in changes)
      for (final fileEdit in change.change.edits) ...fileEdit.edits,
  ];
  return SourceEdit.applySequence(source, edits);
}
