import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces Fluvie's layering law: dependencies point **down only**
/// (CLAUDE.md). `core` depends on nothing; `timing` only on `core`; feature
/// layers on `core` + `timing` but **never** on `diagnostics`.
///
/// The rule is purely path-based. It reads the importing file's layer from its
/// `lib/src/<layer>/` path and the imported `package:fluvie/src/<layer>/` URI,
/// then flags an import that points up or sideways into a forbidden layer. No
/// quick-fix: an upward import is a design break the author must resolve by
/// moving code or introducing a downward seam.
class Layering extends DartLintRule {
  /// Creates the rule with its fixed [LintCode].
  const Layering() : super(code: _code);

  static const _code = LintCode(
    name: 'layering',
    problemMessage:
        'Layering violation: this layer must not import that one. '
        'Dependencies point down only (core <- timing <- features <- '
        'diagnostics).',
    correctionMessage:
        'Move the shared code down, or mediate it with an interface in a '
        'lower layer.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Layers a feature file must never import (they sit above it or aside it).
  static const _forbiddenFromCore = {
    'timing',
    'rendering',
    'animation',
    'composition',
    'elements',
    'effects',
    'media',
    'audio',
    'theme',
    'templates',
    'captions',
    'diagnostics',
  };
  static const _forbiddenFromTiming = {
    'rendering',
    'animation',
    'composition',
    'elements',
    'effects',
    'media',
    'audio',
    'theme',
    'templates',
    'captions',
    'diagnostics',
  };
  static const _forbiddenFromFeature = {'diagnostics'};

  static final _importLayer = RegExp('package:fluvie/src/([^/]+)/');
  static final _pathLayer = RegExp(r'/src/([^/]+)/[^/]*\.dart$');

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final fromLayer = _layerOfPath(resolver.path);
    if (fromLayer == null) return;
    final forbidden = _forbiddenFor(fromLayer);
    if (forbidden == null) return;
    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue;
      if (uri == null) return;
      final toLayer = _importLayer.firstMatch(uri)?.group(1);
      if (toLayer == null) return;
      if (forbidden.contains(toLayer)) reporter.atNode(node, _code);
    });
  }

  static Set<String>? _forbiddenFor(String layer) => switch (layer) {
    'core' => _forbiddenFromCore,
    'timing' => _forbiddenFromTiming,
    'diagnostics' => null,
    _ => _forbiddenFromFeature,
  };

  /// Extracts `<layer>` from a `.../src/<layer>/<file>.dart` path, or `null`
  /// when the file is not inside a `src/<layer>/` tree (then the rule is
  /// silent, the conservative direction). Only `package:fluvie/src/...`
  /// imports are ever checked, so a non-fluvie file with a coincidental
  /// `src/<layer>/` path imports nothing flaggable.
  static String? _layerOfPath(String path) {
    final normalized = path.replaceAll(r'\', '/');
    return _pathLayer.firstMatch(normalized)?.group(1);
  }
}
