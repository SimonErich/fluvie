import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:fluvie_lints/src/rules/animation_exceeds_window.dart';
import 'package:fluvie_lints/src/rules/conflicting_keyframe_fields.dart';
import 'package:fluvie_lints/src/rules/cyclic_trigger.dart';
import 'package:fluvie_lints/src/rules/dangling_anchor.dart';
import 'package:fluvie_lints/src/rules/deprecated_member.dart';
import 'package:fluvie_lints/src/rules/layering.dart';
import 'package:fluvie_lints/src/rules/no_src_import.dart';
import 'package:fluvie_lints/src/rules/relative_outside_scope.dart';
import 'package:fluvie_lints/src/rules/unused_anchor.dart';

/// The Fluvie rule set, in one place so `custom_lint` and programmatic callers
/// (the Playground's snippet validator) share the exact same rules.
///
/// The rules split three ways: structural law (`no_src_import`, `layering`),
/// migration (`deprecated_member`), and the conservative timing-semantics family
/// (`dangling_anchor`, `cyclic_trigger`, `unused_anchor`,
/// `animation_exceeds_window`, `conflicting_keyframe_fields`,
/// `relative_outside_scope`). The timing rules are AST-syntactic and stay silent
/// whenever an argument is not statically decidable, so they never raise a false
/// positive on real code. The structural rules read a file's `lib/` path and so
/// stay silent on a standalone snippet, which is why running the whole set
/// against an isolated file is safe.
const List<DartLintRule> fluvieLintRules = [
  NoSrcImport(),
  Layering(),
  DeprecatedMember(),
  DanglingAnchor(),
  CyclicTrigger(),
  UnusedAnchor(),
  AnimationExceedsWindow(),
  ConflictingKeyframeFields(),
  RelativeOutsideScope(),
];

/// Entry point read by `custom_lint` to load the Fluvie rule set.
PluginBase createPlugin() => _FluvieLintsPlugin();

final class _FluvieLintsPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => fluvieLintRules;
}
