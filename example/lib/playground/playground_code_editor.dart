import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_example/playground/default_playground_code.dart';
import 'package:fluvie_example/playground/playground_view_model.dart';
import 'package:fluvie_example/theme/fluvie_code_theme.dart';
import 'package:fluvie_example/theme/fluvie_colors.dart';
import 'package:fluvie_example/theme/fluvie_text_theme.dart';
import 'package:fluvie_example/theme/widgets/code_window.dart';
import 'package:fluvie_server/client.dart';
import 'package:highlight/languages/dart.dart' as highlight_dart;

/// The single Dart [CodeController] the Playground edits, held in a provider so
/// the editor, the Render action, and the AI Assistant all read and write the
/// same source.
///
/// Seeded with [defaultPlaygroundCode]. Set `fullText` to replace the whole
/// snippet (the AI Assistant does this with freshly generated code); reading
/// `fullText` gives the complete source for validation and rendering.
final playgroundCodeControllerProvider = Provider<CodeController>((ref) {
  final controller = CodeController(
    text: defaultPlaygroundCode,
    language: highlight_dart.dart,
    // A no-op so the built-in analyzer never overwrites the markers we set from
    // the server's validation (which runs only on Render).
    analyzer: const _NoOpAnalyzer(),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// The Playground's Dart editor: a syntax-highlighted [CodeField] whose gutter
/// markers and one-line "N problems" summary come from the server's validation.
///
/// Validation runs only when the user hits Render (driven by the parent
/// `Playground`), never on its own; the built-in analyzer is a no-op so it
/// cannot overwrite the server-sourced markers in [PlaygroundViewModel].
final class PlaygroundCodeEditor extends ConsumerWidget {
  /// Creates the editor over the shared [playgroundCodeControllerProvider].
  const PlaygroundCodeEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(playgroundCodeControllerProvider);
    final state = ref.watch(playgroundViewModelProvider);
    controller.analysisResult = AnalysisResult(
      issues: [for (final d in state.diagnostics) _toIssue(d)],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CodeWindow(
            filename: 'video.dart',
            child: CodeTheme(
              data: CodeThemeData(styles: fluvieCodeTheme),
              child: CodeField(
                controller: controller,
                expands: true,
                background: FluvieColors.dark,
                textStyle: fluvieMono(
                  fontSize: 12.5,
                  height: 1.5,
                  color: FluvieColors.codeText,
                ),
              ),
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
