import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags a `Trigger.after(a)` / `Trigger.whenStarts(a)` whose anchor `a` is
/// never attached to an element (`dangling_anchor`). The resolver would have
/// nothing to wait for.
///
/// Conservative and syntactic. It fires only when the anchor is a **local
/// variable** inside one function body, that body references it from a
/// `Trigger.after`/`Trigger.whenStarts`, and that same body never passes it as
/// the `anchor:` argument of any call. A local can only be attached in its own
/// body, so an unseen attachment is impossible — the safe direction. An anchor
/// stored in a field, a parameter, or a top-level variable is left alone (it
/// may be attached in another file). No quick-fix: the author must attach it.
class DanglingAnchor extends DartLintRule {
  /// Creates the rule with its fixed [LintCode].
  const DanglingAnchor() : super(code: _code);

  static const _code = LintCode(
    name: 'dangling_anchor',
    problemMessage:
        "Anchor '{0}' is waited on by a Trigger but never attached to an "
        'element. The Trigger has nothing to resolve against.',
    correctionMessage: 'Attach it: SomeElement().animate([...], anchor: {0}).',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionBody((body) {
      final scan = _BodyScan()..visit(body);
      for (final entry in scan.triggeredAnchors.entries) {
        final name = entry.key;
        if (!scan.localAnchors.contains(name)) continue;
        if (scan.attachedAnchors.contains(name)) continue;
        reporter.atNode(entry.value, _code, arguments: [name]);
      }
    });
  }

  @override
  List<DartFix> getFixes() => const [];
}

/// Gathers, within one function body: anchors declared as locals, anchor names
/// passed as an `anchor:` argument (attached), and the names a
/// `Trigger.after`/`whenStarts` waits on (with the offending node).
class _BodyScan extends RecursiveAstVisitor<void> {
  final Set<String> localAnchors = {};
  final Set<String> attachedAnchors = {};
  final Map<String, SimpleIdentifier> triggeredAnchors = {};

  void visit(FunctionBody body) => body.accept(this);

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final init = node.initializer;
    if (init is InstanceCreationExpression && init.constructorName.type.name.lexeme == 'Anchor') {
      localAnchors.add(node.name.lexeme);
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    if (node.name.label.name == 'anchor') {
      final value = node.expression;
      if (value is SimpleIdentifier) attachedAnchors.add(value.name);
    }
    super.visitNamedExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isAfterOrWhenStarts(node)) {
      final arg = node.argumentList.arguments.singleOrNull;
      if (arg is SimpleIdentifier) {
        triggeredAnchors.putIfAbsent(arg.name, () => arg);
      }
    }
    super.visitMethodInvocation(node);
  }

  /// Whether [node] is `Trigger.after(x)` or `Trigger.whenStarts(x)`.
  static bool _isAfterOrWhenStarts(MethodInvocation node) {
    final name = node.methodName.name;
    if (name != 'after' && name != 'whenStarts') return false;
    final target = node.target;
    return target is SimpleIdentifier && target.name == 'Trigger';
  }
}
