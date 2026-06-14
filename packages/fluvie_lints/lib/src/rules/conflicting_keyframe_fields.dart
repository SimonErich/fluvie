import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags two animations in one `.animate([...])` list that write the same
/// `Keyframe` field over the same window (`conflicting_keyframe_fields`): the
/// second silently overrides the first.
///
/// Conservative and syntactic. It only considers `Animation.from`/`to`/`fromTo`
/// entries that carry **no** explicit `at:` — those default to `Trigger.auto`
/// and span the whole element window, so two of them always overlap. It reads
/// the explicitly-named `Keyframe(...)` fields of each and flags a field set by
/// two or more such entries. Any entry with an explicit `at:`, a non-literal
/// keyframe, or a variable is skipped, so a deliberately sequenced pair never
/// trips. The `origin` field (a pivot, not an animated value) is ignored. No
/// quick-fix: the author decides which write wins.
class ConflictingKeyframeFields extends DartLintRule {
  /// Creates the rule with its fixed [LintCode].
  const ConflictingKeyframeFields() : super(code: _code);

  static const _code = LintCode(
    name: 'conflicting_keyframe_fields',
    problemMessage:
        "Two animations write '{0}' over the same window; the later one wins. "
        'Merge them or stagger their timing.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const _ignoredFields = {'origin'};

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'animate') return;
      final byField = <String, List<AstNode>>{};
      for (final field in _fullWindowFields(node)) {
        byField.putIfAbsent(field.name, () => []).add(field.node);
      }
      for (final entry in byField.entries) {
        if (entry.value.length < 2) continue;
        for (final node in entry.value) {
          reporter.atNode(node, _code, arguments: [entry.key]);
        }
      }
    });
  }

  /// Every `Keyframe(...)` field set by a full-window animation entry of an
  /// `.animate([...])` call, paired with the offending argument node.
  static Iterable<({String name, AstNode node})> _fullWindowFields(
    MethodInvocation animate,
  ) sync* {
    final list = animate.argumentList.arguments.whereType<ListLiteral>().firstOrNull;
    if (list == null) return;
    for (final element in list.elements) {
      if (element is! InstanceCreationExpression) continue;
      if (!_isFullWindowKeyframeAnimation(element)) continue;
      yield* _keyframeFieldsOf(element);
    }
  }

  /// Whether [call] is `Animation.from/to/fromTo(...)` with no explicit `at:`.
  static bool _isFullWindowKeyframeAnimation(InstanceCreationExpression call) {
    final ctor = call.constructorName;
    if (ctor.type.name.lexeme != 'Animation') return false;
    const keyframeFactories = {'from', 'to', 'fromTo'};
    if (!keyframeFactories.contains(ctor.name?.name)) return false;
    for (final arg in call.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'at') return false;
    }
    return true;
  }

  /// The explicitly-named, animated fields of every `Keyframe(...)` literal in
  /// [call]'s arguments.
  static Iterable<({String name, AstNode node})> _keyframeFieldsOf(
    InstanceCreationExpression call,
  ) sync* {
    final finder = _KeyframeFieldFinder();
    call.argumentList.accept(finder);
    for (final field in finder.fields) {
      if (!_ignoredFields.contains(field.name)) yield field;
    }
  }

  @override
  List<DartFix> getFixes() => const [];
}

/// Collects the named fields of every `Keyframe(...)` constructor it visits.
class _KeyframeFieldFinder extends RecursiveAstVisitor<void> {
  final List<({String name, AstNode node})> fields = [];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.name.lexeme == 'Keyframe') {
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          fields.add((name: arg.name.label.name, node: arg));
        }
      }
    }
    super.visitInstanceCreationExpression(node);
  }
}
