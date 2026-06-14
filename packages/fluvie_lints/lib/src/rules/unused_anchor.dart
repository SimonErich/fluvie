import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/diagnostic/diagnostic.dart' show Diagnostic;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags an `Anchor` that is declared but never referenced
/// (`unused_anchor`). A dangling handle is dead weight and usually a sign the
/// author forgot to wire a `Trigger.after(...)`.
///
/// Conservative and syntactic: it only fires on a local or top-level `final`
/// whose initializer is exactly `Anchor(...)` and whose name appears nowhere
/// else in the same file. It never inspects a value that flows through a field,
/// a parameter, or another expression, so a real reference it cannot see keeps
/// it silent (zero false positives). The quick-fix removes the declaration.
class UnusedAnchor extends DartLintRule {
  /// Creates the rule with its fixed [LintCode].
  const UnusedAnchor() : super(code: _code);

  static const _code = LintCode(
    name: 'unused_anchor',
    problemMessage:
        "Anchor '{0}' is declared but never referenced. Remove it, or wire a "
        'Trigger to it.',
    correctionMessage: 'Remove the unused anchor.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((unit) {
      final counts = _NameUseCounter()..visit(unit);
      for (final declaration in _anchorDeclarations(unit)) {
        final name = declaration.name.lexeme;
        // The declaration name is a Token, not a SimpleIdentifier, so the
        // counter only sees genuine references: zero means unused.
        if ((counts.uses[name] ?? 0) == 0) {
          reporter.atToken(declaration.name, _code, arguments: [name]);
        }
      }
    });
  }

  /// The `final x = Anchor(...)` declarations reachable in [unit].
  static Iterable<VariableDeclaration> _anchorDeclarations(
    CompilationUnit unit,
  ) sync* {
    final visitor = _AnchorDeclVisitor();
    unit.accept(visitor);
    yield* visitor.declarations;
  }

  @override
  List<DartFix> getFixes() => [_RemoveAnchor()];
}

/// Counts how many times each simple name is *referenced* in a unit. A
/// variable's declaration name is a `Token`, not a `SimpleIdentifier`, so it is
/// never counted: zero references means the variable is unused.
class _NameUseCounter extends RecursiveAstVisitor<void> {
  final Map<String, int> uses = {};

  void visit(CompilationUnit unit) => unit.accept(this);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    uses.update(node.name, (v) => v + 1, ifAbsent: () => 1);
    super.visitSimpleIdentifier(node);
  }
}

/// Collects `final x = Anchor(...)` *local* and *top-level* variable
/// declarations. Class fields are skipped: a field can be referenced from
/// another file (via `this`/`widget`/an instance), which the single-file name
/// counter cannot see, so flagging one would be a false positive.
class _AnchorDeclVisitor extends RecursiveAstVisitor<void> {
  final List<VariableDeclaration> declarations = [];

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (_isAnchorCreation(node.initializer) && !_isField(node)) {
      declarations.add(node);
    }
    super.visitVariableDeclaration(node);
  }

  /// Whether [node] is a class/mixin/extension field (its list sits in a
  /// `FieldDeclaration`), as opposed to a local or top-level variable.
  static bool _isField(VariableDeclaration node) => node.parent?.parent is FieldDeclaration;
}

/// Whether [expression] is exactly an `Anchor(...)` instance creation.
bool _isAnchorCreation(Expression? expression) {
  if (expression is! InstanceCreationExpression) return false;
  final ctor = expression.constructorName;
  return ctor.type.name.lexeme == 'Anchor' && ctor.name == null;
}

class _RemoveAnchor extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    Diagnostic analysisError,
    List<Diagnostic> others,
  ) {
    context.registry.addVariableDeclaration((node) {
      if (!node.name.sourceRange.intersects(analysisError.sourceRange)) return;
      final parent = node.parent;
      if (parent is! VariableDeclarationList) return;
      // Only remove a sole single-variable statement, never one declarator of
      // a multi-variable list (that would need finer splicing).
      if (parent.variables.length != 1) return;
      // The whole declaration to delete: a local statement or a top-level
      // declaration. Class fields are never reported, so they never reach here.
      final statement = parent.parent;
      if (statement is! VariableDeclarationStatement && statement is! TopLevelVariableDeclaration) {
        return;
      }
      reporter
          .createChangeBuilder(message: 'Remove the unused anchor', priority: 80)
          .addDartFileEdit((edit) {
            edit.addDeletion(SourceRange(statement!.offset, statement.length));
          });
    });
  }
}
