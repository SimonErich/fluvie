import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags a trigger cycle: element A waits for B while B waits for A
/// (`cyclic_trigger`). The resolver could never assign a start
/// frame to either, so this is always a bug.
///
/// Conservative and syntactic. Within one function body it reads each
/// `.animate([...], anchor: A)` call, takes A as the owner, and adds an edge
/// `A -> B` for every `Trigger.after(B)` / `Trigger.whenStarts(B)` inside that
/// call's animation list. It then looks for a cycle in that graph and flags
/// each `.animate` whose owner sits on one. Anchors are matched by simple name
/// only, so an indirected anchor (through a field, a helper, another file)
/// builds no edge and never trips the rule. No quick-fix: untangling the
/// schedule is the author's call.
class CyclicTrigger extends DartLintRule {
  /// Creates the rule with its fixed [LintCode].
  const CyclicTrigger() : super(code: _code);

  static const _code = LintCode(
    name: 'cyclic_trigger',
    problemMessage:
        'Trigger cycle: these elements wait on each other, so neither can '
        'ever start.',
    correctionMessage: 'Break the cycle: one element must start on its own.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionBody((body) {
      final scan = _GraphScan()..visit(body);
      final onCycle = _nodesOnAnyCycle(scan.edges);
      for (final entry in scan.ownerNodes.entries) {
        if (onCycle.contains(entry.key)) {
          reporter.atNode(entry.value, _code);
        }
      }
    });
  }

  /// The set of nodes that participate in any cycle of the directed [edges].
  static Set<String> _nodesOnAnyCycle(Map<String, Set<String>> edges) {
    final onCycle = <String>{};
    final visiting = <String>{};
    final done = <String>{};

    void dfs(String node, List<String> stack) {
      visiting.add(node);
      stack.add(node);
      for (final next in edges[node] ?? const <String>{}) {
        if (visiting.contains(next)) {
          final start = stack.indexOf(next);
          if (start >= 0) onCycle.addAll(stack.sublist(start));
        } else if (!done.contains(next)) {
          dfs(next, stack);
        }
      }
      stack.removeLast();
      visiting.remove(node);
      done.add(node);
    }

    for (final node in edges.keys) {
      if (!done.contains(node)) dfs(node, <String>[]);
    }
    return onCycle;
  }

  @override
  List<DartFix> getFixes() => const [];
}

/// Builds the `owner -> dependency` edge set from `.animate(..., anchor: A)`
/// calls, mapping each owner name to the `.animate` node that declared it.
class _GraphScan extends RecursiveAstVisitor<void> {
  final Map<String, Set<String>> edges = {};
  final Map<String, MethodInvocation> ownerNodes = {};

  void visit(FunctionBody body) => body.accept(this);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'animate') {
      final owner = _ownerOf(node);
      if (owner != null) {
        ownerNodes[owner] = node;
        edges.putIfAbsent(owner, () => {}).addAll(_dependenciesOf(node));
      }
    }
    super.visitMethodInvocation(node);
  }

  /// The `anchor:` identifier of an `.animate(...)` call, or `null`.
  static String? _ownerOf(MethodInvocation node) {
    for (final arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'anchor') {
        final value = arg.expression;
        if (value is SimpleIdentifier) return value.name;
      }
    }
    return null;
  }

  /// Every `Trigger.after(B)` / `Trigger.whenStarts(B)` anchor name reachable
  /// inside the `.animate(...)` argument list.
  static Set<String> _dependenciesOf(MethodInvocation node) {
    final finder = _TriggerDepFinder();
    node.argumentList.accept(finder);
    return finder.deps;
  }
}

/// Collects the anchor names a `Trigger.after`/`whenStarts` waits on.
class _TriggerDepFinder extends RecursiveAstVisitor<void> {
  final Set<String> deps = {};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    final target = node.target;
    if ((name == 'after' || name == 'whenStarts') &&
        target is SimpleIdentifier &&
        target.name == 'Trigger') {
      final arg = node.argumentList.arguments.singleOrNull;
      if (arg is SimpleIdentifier) deps.add(arg.name);
    }
    super.visitMethodInvocation(node);
  }
}
