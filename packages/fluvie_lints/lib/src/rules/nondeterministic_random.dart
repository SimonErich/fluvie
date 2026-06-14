import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags wall-clock and unseeded randomness, the determinism breach (CLAUDE.md:
/// "no `DateTime.now()`, no unseeded `dart:math` `Random()` in render code").
/// The pre-commit grep-gate enforces the same patterns; this rule is the
/// editor-and-analyzer authority over the overlap.
///
/// Because a Fluvie video is render code end to end, the ban is not narrowed to
/// a `build` method or a frame callback: the rule fires wherever the construct
/// appears in the analyzed code, since the library has no legitimate use for an
/// unseeded clock or `Random`.
///
/// It fires on `DateTime.now()` and on an *argument-less* `Random()`. A seeded
/// `Random(seed)` is the deterministic path and is left alone, as is
/// `Random.secure()` (never used in render code, but not a determinism trap).
/// No quick-fix: the author must thread a seed through `noise(seed)` /
/// `random(seed)`. Syntactic only, so it never chases a `Random` aliased
/// behind a typedef.
class NondeterministicRandom extends DartLintRule {
  /// Creates the rule with its fixed [LintCode].
  const NondeterministicRandom() : super(code: _code);

  static const _code = LintCode(
    name: 'nondeterministic_random',
    problemMessage:
        'Non-deterministic source in render code. The frame is the only '
        'clock, and randomness must be seeded.',
    correctionMessage:
        'Use a frame-derived value, or seed it: random(seed) / noise(seed) '
        '/ Random(seed).',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      if (_isUnseededRandom(node) || _isDateTimeNow(node)) {
        reporter.atNode(node, _code);
      }
    });
  }

  /// An unseeded `Random()`: the constructor name is `Random`, it is the
  /// unnamed constructor, and it is called with no arguments. `Random(seed)`
  /// and `Random.secure()` carry an argument or a name and are skipped.
  static bool _isUnseededRandom(InstanceCreationExpression node) {
    final type = node.constructorName.type;
    if (type.name.lexeme != 'Random') return false;
    if (node.constructorName.name != null) return false;
    return node.argumentList.arguments.isEmpty;
  }

  /// A `DateTime.now()` call: the named constructor `now` on the type
  /// `DateTime` (a factory constructor, so it parses as an instance creation).
  static bool _isDateTimeNow(InstanceCreationExpression node) {
    final ctor = node.constructorName;
    return ctor.type.name.lexeme == 'DateTime' && ctor.name?.name == 'now';
  }
}
