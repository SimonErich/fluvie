import 'package:analyzer/diagnostic/diagnostic.dart' show Diagnostic;
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A 1.0 replacement for a pre-1.0 type: the new type name
/// (`to`) plus an optional `note`. A non-`null` `note` means the rewrite is not
/// a pure rename (for example `KenBurnsImage` becomes an `Image` plus an
/// `Animation.kenBurns()`), so the quick-fix renames the type and the note
/// tells the author what else to add.
typedef _Replacement = ({String to, String? note});

const Map<String, _Replacement> _consolidation = {
  // Layout widgets: the `V`-prefixed shims collapse onto Flutter's names.
  'VStack': (to: 'Stack', note: null),
  'VColumn': (to: 'Column', note: null),
  'VRow': (to: 'Row', note: null),
  'VCenter': (to: 'Center', note: null),
  'VPadding': (to: 'Padding', note: null),
  'VPositioned': (to: 'Positioned', note: null),
  'VSizedBox': (to: 'SizedBox', note: null),
  // Video embedding unifies under `Clip`.
  'EmbeddedVideo': (to: 'Clip', note: null),
  'VideoSequence': (to: 'Clip', note: null),
  // Animation shims unify under `Animation`.
  'PropAnimation': (to: 'Animation', note: null),
  'EntryAnimation': (to: 'Animation', note: null),
  'AnimatedProp': (to: 'Animation', note: 'attach it through .animate([...]).'),
  // Text/data elements rename to their 1.0 names.
  'TypewriterText': (to: 'Typewriter', note: null),
  'CounterText': (to: 'Counter', note: null),
  'DataDrivenText': (to: 'Counter', note: null),
  'AnimatedChart': (to: 'Chart', note: null),
  // Image shims fold into `Image` plus a preset.
  'KenBurnsImage': (to: 'Image', note: 'add Animation.kenBurns() via .animate.'),
  'PhotoCard': (to: 'Image', note: 'wrap it in a Frame.* recipe.'),
  // Encoding config renames to the `Export.*` factories.
  'EncodingConfig': (to: 'Export', note: 'use the Export.* factories.'),
};

/// Drives migration off the pre-1.0 names with a rename
/// quick-fix per old → new pair.
///
/// No member in the 1.0 library actually carries these names, so the rule
/// never fires on Fluvie's own code; it exists to guide a user upgrading old
/// source. It matches a bare type name syntactically (a `NamedType`), so it
/// stays silent on an unrelated local variable that happens to share a name.
/// Being name-only, it cannot tell a user's unrelated type of the same name
/// from the retired Fluvie one, so a type named, say, `Loop` from another
/// library is flagged too; the quick-fix is opt-in, so this is guidance, not a
/// forced rewrite. Where the new shape is not a pure rename, the message says
/// what else to add.
class DeprecatedMember extends DartLintRule {
  /// Creates the rule with its fixed [LintCode].
  const DeprecatedMember() : super(code: _code);

  static const _code = LintCode(
    name: 'deprecated_member',
    problemMessage: "'{0}' was consolidated in 1.0. Use '{1}' instead{2}",
    correctionMessage: "Rename '{0}' to '{1}'.",
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addNamedType((node) {
      final old = node.name.lexeme;
      final replacement = _consolidation[old];
      if (replacement == null) return;
      final note = replacement.note == null ? '.' : ' (${replacement.note})';
      reporter.atNode(node, _code, arguments: [old, replacement.to, note]);
    });
  }

  @override
  List<DartFix> getFixes() => [_RenameToNewMember()];
}

class _RenameToNewMember extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    Diagnostic analysisError,
    List<Diagnostic> others,
  ) {
    context.registry.addNamedType((node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      final replacement = _consolidation[node.name.lexeme];
      if (replacement == null) return;
      reporter
          .createChangeBuilder(
            message: "Rename to '${replacement.to}'",
            priority: 80,
          )
          .addDartFileEdit((edit) {
            edit.addSimpleReplacement(node.name.sourceRange, replacement.to);
          });
    });
  }
}
