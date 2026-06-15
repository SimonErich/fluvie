import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/spring_solver.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/timing/plan/animation_plan.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// How many frames [plan] runs for, within [elementScope].
///
/// The innermost cascade layer — animation-explicit timing wins over every
/// inherited default:
///
/// * a [Tween] resolves its own duration against [elementScope];
/// * a [Spring] has no fixed duration — its [SpringSolver.settleFrames] at the
///   scope's fps becomes the window; a zero-damping spring never settles, so
///   the solver's [ArgumentError] propagates;
/// * no timing falls back to [merged]'s duration — [merged] comes from
///   [mergeDefaultsChain], whose cascade ends in [Defaults.package], so the
///   duration is always present. A relative default measures the element's
///   own window, not the scene.
int effectiveDurationFrames(AnimationPlan plan, Defaults merged, TimeScopeData elementScope) =>
    switch (plan.timing) {
      final Tween tween => tween.duration.resolveFrames(elementScope),
      final Spring spring => SpringSolver(spring).settleFrames(elementScope.fps),
      null => merged.duration!.resolveFrames(elementScope),
    };

/// Merges the inherited [Defaults] cascade for one element: element-level
/// wins over [scene], which wins over [video], which wins over the
/// [FluvieTheme] [theme] layer, which wins over [Defaults.package].
///
/// Every field cascades independently, and the package layer is total, so
/// the result always has a non-null duration and ease. The [theme] layer sits
/// directly above the package default: an unset (all-null) [theme] leaves the
/// cascade byte-identical, and an explicit `Video.motionDefaults` always beats
/// it (the precedence pin). Animation-explicit timing sits *above* this whole
/// chain — see [effectiveDurationFrames].
Defaults mergeDefaultsChain({
  Defaults? element,
  Defaults? scene,
  Defaults? video,
  Defaults? theme,
}) {
  var merged = (theme ?? const Defaults()).mergeOver(Defaults.package);
  merged = (video ?? const Defaults()).mergeOver(merged);
  merged = (scene ?? const Defaults()).mergeOver(merged);
  return (element ?? const Defaults()).mergeOver(merged);
}
