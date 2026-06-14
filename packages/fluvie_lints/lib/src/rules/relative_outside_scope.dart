import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags a relative time used where no enclosing duration exists to scale it
/// (`relative_outside_scope`). `0.x.relative` means "a fraction of
/// the enclosing window", so it is meaningless where that window is the very
/// duration being declared.
///
/// Conservative and syntactic. A relative time is almost always validly scoped
/// (the scene is the fallback), so the rule fires on the one
/// statically-certain misuse: a `.relative` (or `Time.relative(...)`) passed as
/// the `duration:` of a `Scene(...)` or `Video(...)`. A scene or video defines
/// the scope, so its own length cannot be a fraction of itself. Every other
/// `.relative` is left alone. No quick-fix: the author must pick a concrete
/// length.
class RelativeOutsideScope extends DartLintRule {
  /// Creates the rule with its fixed [LintCode].
  const RelativeOutsideScope() : super(code: _code);

  static const _code = LintCode(
    name: 'relative_outside_scope',
    problemMessage:
        'A relative time has no enclosing duration to scale here. A '
        "Scene/Video duration must be concrete (for example '5.seconds').",
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const _scopeDefiningTypes = {'Scene', 'Video'};

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final type = node.constructorName.type.name.lexeme;
      if (!_scopeDefiningTypes.contains(type)) return;
      for (final arg in node.argumentList.arguments) {
        if (arg is! NamedExpression || arg.name.label.name != 'duration') {
          continue;
        }
        if (_isRelativeTime(arg.expression)) {
          reporter.atNode(arg.expression, _code);
        }
      }
    });
  }

  /// Whether [expression] is a `<num>.relative` getter or a `Time.relative(...)`
  /// constructor.
  static bool _isRelativeTime(Expression expression) {
    if (expression is PropertyAccess) {
      return expression.propertyName.name == 'relative';
    }
    if (expression is InstanceCreationExpression) {
      final ctor = expression.constructorName;
      return ctor.type.name.lexeme == 'Time' && ctor.name?.name == 'relative';
    }
    return false;
  }

  @override
  List<DartFix> getFixes() => const [];
}
