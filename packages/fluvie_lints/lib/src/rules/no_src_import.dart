import 'package:analyzer/diagnostic/diagnostic.dart' show Diagnostic;
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags a `package:<other>/src/...` import, the single-barrel violation
/// (CLAUDE.md: "Nothing imports another package's `src/`").
///
/// The dart `implementation_imports` lint covers the same ground, but this rule
/// ships the Fluvie message and a quick-fix that rewrites the import to the
/// offending package's public barrel. Same-package `src/` imports (Fluvie's own
/// internal wiring) are allowed: only a *cross-package* `src/` import trips.
class NoSrcImport extends DartLintRule {
  /// Creates the rule with its fixed [LintCode].
  const NoSrcImport() : super(code: _code);

  static const _code = LintCode(
    name: 'no_src_import',
    problemMessage:
        "Don't import another package's 'src/'. Import its public barrel "
        'instead (the single-entry rule).',
    correctionMessage: "Replace with 'package:<pkg>/<pkg>.dart'.",
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static final _crossPackageSrc = RegExp('^package:([^/]+)/src/');

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // The single-barrel rule governs library code. Test files legitimately
    // access package internals (mirroring the built-in implementation_imports
    // lint, which also exempts test/).
    if (!resolver.path.contains('/lib/')) return;
    final ownPackage = _packageOf(resolver.path);
    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue;
      if (uri == null) return;
      final match = _crossPackageSrc.firstMatch(uri);
      if (match == null) return;
      // Same-package src import is the library's own internal wiring; allow it.
      if (match.group(1) == ownPackage) return;
      reporter.atNode(node, _code);
    });
  }

  /// Reads the importing file's own package name from its `lib/` path so a
  /// same-package `src/` import is not flagged. Returns `null` when the path
  /// shape is unfamiliar (then every cross-package `src/` import still trips,
  /// which is the safe direction).
  static String? _packageOf(String path) {
    final normalized = path.replaceAll(r'\', '/');
    final libIndex = normalized.indexOf('/lib/');
    if (libIndex < 0) return null;
    final before = normalized.substring(0, libIndex);
    final lastSlash = before.lastIndexOf('/');
    return lastSlash < 0 ? before : before.substring(lastSlash + 1);
  }

  @override
  List<DartFix> getFixes() => [_RewriteToBarrel()];
}

class _RewriteToBarrel extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    Diagnostic analysisError,
    List<Diagnostic> others,
  ) {
    context.registry.addImportDirective((node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      final uri = node.uri.stringValue;
      if (uri == null) return;
      final match = NoSrcImport._crossPackageSrc.firstMatch(uri);
      if (match == null) return;
      final pkg = match.group(1);
      reporter
          .createChangeBuilder(
            message: "Import the '$pkg' barrel",
            priority: 80,
          )
          .addDartFileEdit((edit) {
            edit.addSimpleReplacement(
              node.uri.sourceRange,
              "'package:$pkg/$pkg.dart'",
            );
          });
    });
  }
}
