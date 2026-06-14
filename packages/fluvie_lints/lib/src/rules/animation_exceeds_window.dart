import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A literal `Time` in one unit: a `<value>.frames` or `<value>.seconds`.
typedef _Literal = ({double value, String unit});

/// Flags an animation whose statically-known duration is longer than its
/// element's statically-known window (`animation_exceeds_window`): the tail
/// would be clipped.
///
/// Conservative and syntactic. It compares only when both sides are literal and
/// share a unit: a `.animate([Animation.x(duration: D)], window: A.to(B))`
/// where `D`, `A`, `B` are all `<num>.frames` (or all `<num>.seconds`). If any
/// bound is a variable, a relative time, or a different unit (frames vs seconds
/// needs an fps the rule does not have), it stays silent. No quick-fix: the
/// author chooses whether to shorten the animation or widen the window.
class AnimationExceedsWindow extends DartLintRule {
  /// Creates the rule with its fixed [LintCode].
  const AnimationExceedsWindow() : super(code: _code);

  static const _code = LintCode(
    name: 'animation_exceeds_window',
    problemMessage:
        'This animation is longer than its element window, so its tail is '
        'clipped. Shorten the duration or widen the window.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'animate') return;
      final window = _windowLength(node);
      if (window == null) return;
      for (final duration in _durationsIn(node)) {
        if (duration.unit == window.unit && duration.value > window.value) {
          reporter.atNode(duration.node, _code);
        }
      }
    });
  }

  /// The length of a literal `window: A.to(B)` argument, or `null` when it is
  /// absent or not a same-unit literal range.
  static _Literal? _windowLength(MethodInvocation animate) {
    for (final arg in animate.argumentList.arguments) {
      if (arg is! NamedExpression || arg.name.label.name != 'window') continue;
      final range = arg.expression;
      if (range is! MethodInvocation || range.methodName.name != 'to') {
        return null;
      }
      final start = _literalTime(range.target);
      final end = _literalTime(range.argumentList.arguments.singleOrNull);
      if (start == null || end == null || start.unit != end.unit) return null;
      return (value: end.value - start.value, unit: start.unit);
    }
    return null;
  }

  /// Every literal `duration:` in the animation list of [animate], paired with
  /// the node to flag.
  static Iterable<({double value, String unit, AstNode node})> _durationsIn(
    MethodInvocation animate,
  ) sync* {
    final finder = _DurationFinder();
    animate.argumentList.accept(finder);
    yield* finder.durations;
  }

  @override
  List<DartFix> getFixes() => const [];
}

/// Reads a `<num>.frames` / `<num>.seconds` literal, or `null` for anything
/// else (a variable, a relative time, a computed value). A numeric receiver
/// with a `.frames`/`.seconds` getter always parses as a [PropertyAccess].
_Literal? _literalTime(Object? expression) {
  if (expression is! PropertyAccess) return null;
  final unit = expression.propertyName.name;
  final value = _numberOf(expression.target);
  if (value == null || (unit != 'frames' && unit != 'seconds')) return null;
  return (value: value, unit: unit);
}

double? _numberOf(Expression? expression) => switch (expression) {
  IntegerLiteral(:final value) => value?.toDouble(),
  DoubleLiteral(:final value) => value,
  _ => null,
};

/// Collects literal `duration:` arguments in an animation list.
class _DurationFinder extends RecursiveAstVisitor<void> {
  final List<({double value, String unit, AstNode node})> durations = [];

  @override
  void visitNamedExpression(NamedExpression node) {
    if (node.name.label.name == 'duration') {
      final literal = _literalTime(node.expression);
      if (literal != null) {
        durations.add((
          value: literal.value,
          unit: literal.unit,
          node: node.expression,
        ));
      }
    }
    super.visitNamedExpression(node);
  }
}
