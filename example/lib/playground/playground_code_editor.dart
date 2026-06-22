import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_example/playground/default_playground_code.dart';
import 'package:fluvie_example/playground/playground_view_model.dart';
import 'package:fluvie_server/client.dart';
import 'package:highlight/languages/dart.dart' as highlight_dart;

/// The Playground's Dart editor: a syntax-highlighted [CodeField] that debounces
/// edits into a validation, then renders the result's diagnostics as gutter
/// markers and a one-line "N problems" summary.
///
/// Validation runs on the server (it never executes the snippet here), so the
/// built-in analyzer is replaced with a no-op and the markers come straight from
/// [PlaygroundViewModel].
final class PlaygroundCodeEditor extends ConsumerStatefulWidget {
  /// Creates the editor, seeded with [defaultPlaygroundCode].
  const PlaygroundCodeEditor({super.key});

  /// Reads the current editor text via the editor's [GlobalKey], so a parent
  /// (the Playground) can render exactly what is on screen.
  static String codeOf(GlobalKey key) {
    final state = key.currentState;
    return state is _PlaygroundCodeEditorState ? state._controller.fullText : '';
  }

  @override
  ConsumerState<PlaygroundCodeEditor> createState() => _PlaygroundCodeEditorState();
}

class _PlaygroundCodeEditorState extends ConsumerState<PlaygroundCodeEditor> {
  static const _debounce = Duration(milliseconds: 500);

  late final CodeController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = CodeController(
      text: defaultPlaygroundCode,
      language: highlight_dart.dart,
      // The default analyzer auto-runs on every edit and overwrites
      // analysisResult; a no-op leaves the server-sourced markers in place.
      analyzer: const _NoOpAnalyzer(),
    );
    _controller.addListener(_onChanged);
    // Validate the seeded snippet once so the editor opens with a verdict.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _validateNow();
    });
  }

  void _onChanged() {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (mounted) _validateNow();
    });
  }

  void _validateNow() =>
      unawaited(ref.read(playgroundViewModelProvider.notifier).validate(_controller.fullText));

  @override
  void dispose() {
    _timer?.cancel();
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playgroundViewModelProvider);
    _controller.analysisResult = AnalysisResult(
      issues: [for (final d in state.diagnostics) _toIssue(d)],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: CodeField(
              controller: _controller,
              expands: true,
              textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ),
        _DiagnosticsSummary(diagnostics: state.diagnostics, validating: state.validating),
      ],
    );
  }
}

Issue _toIssue(ApiCodeDiagnostic d) =>
    Issue(line: d.line, message: d.message, type: _toIssueType(d.severity));

IssueType _toIssueType(ApiDiagnosticSeverity severity) => switch (severity) {
  ApiDiagnosticSeverity.error => IssueType.error,
  ApiDiagnosticSeverity.warning => IssueType.warning,
  ApiDiagnosticSeverity.info => IssueType.info,
};

/// The one-line verdict under the editor: a checking hint, "No problems", or
/// "N problem(s)".
final class _DiagnosticsSummary extends StatelessWidget {
  const _DiagnosticsSummary({required this.diagnostics, required this.validating});

  final List<ApiCodeDiagnostic> diagnostics;
  final bool validating;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme.bodySmall;
    final (IconData icon, Color color, String label) = switch ((validating, diagnostics.length)) {
      (true, _) => (Icons.hourglass_empty, scheme.onSurfaceVariant, 'Checking ...'),
      (false, 0) => (Icons.check_circle_outline, scheme.primary, 'No problems'),
      (false, final n) => (
        Icons.error_outline,
        scheme.error,
        n == 1 ? '1 problem' : '$n problems',
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: theme?.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// An analyzer that never reports issues, so the editor's markers are driven
/// only by the server's validation (not the bundled local heuristics).
final class _NoOpAnalyzer extends AbstractAnalyzer {
  const _NoOpAnalyzer();

  @override
  Future<AnalysisResult> analyze(Code code) async => const AnalysisResult(issues: []);
}
