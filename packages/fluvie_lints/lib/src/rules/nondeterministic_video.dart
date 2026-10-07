import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns about resolved SDK clocks and unseeded randomness inside video trees.
///
/// This conservative check covers expressions inside Fluvie's Video, Scene and
/// FrameBuilder constructors. It excludes application code, unrelated types
/// with the same names and event handlers. Runtime review covers choices made
/// outside these expressions, including widget initialization and factories.
final class NondeterministicVideo extends DartLintRule {
  /// Creates the authoring rule.
  const NondeterministicVideo() : super(code: _code);

  static const _code = LintCode(
    name: 'nondeterministic_video',
    problemMessage:
        '{0} can change video pixels between renders. Use the authored frame, '
        'a fixed timestamp, or an explicit random seed.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(CustomLintResolver resolver, DiagnosticReporter reporter, CustomLintContext context) {
    context.registry.addInstanceCreationExpression((node) {
      final constructor = node.constructorName;
      final element = constructor.element;
      if (element == null) return;
      final type = element.enclosingElement.name;
      final name = constructor.name?.name ?? '';
      final uri = element.library.uri.toString();
      final clock = uri == 'dart:core' && type == 'DateTime' && {'now', 'timestamp'}.contains(name);
      final random =
          uri == 'dart:math' &&
          type == 'Random' &&
          (name == 'secure' ||
              (name.isEmpty || name == 'new') &&
                  (node.argumentList.arguments.isEmpty ||
                      node.argumentList.arguments.length == 1 &&
                          node.argumentList.arguments.first is NullLiteral));
      if (!(clock || random) || !_insideVideo(node)) return;
      reporter.atNode(
        node,
        _code,
        arguments: [if (clock) 'Reading the wall clock' else 'Unseeded randomness'],
      );
    });
  }

  static bool _insideVideo(AstNode node) {
    for (var parent = node.parent; parent != null; parent = parent.parent) {
      if (parent is NamedExpression && parent.name.label.name.startsWith('on')) return false;
      if (parent is! InstanceCreationExpression) continue;
      final element = parent.constructorName.element;
      if (element == null) continue;
      final uri = element.library.uri;
      if (uri.scheme == 'package' &&
          uri.path.startsWith('fluvie/') &&
          {'Video', 'Scene', 'FrameBuilder'}.contains(element.enclosingElement.name)) {
        return true;
      }
    }
    return false;
  }
}
