import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/animation_effect.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/animation/effects/keyframe_animation_effect.dart';
import 'package:fluvie/src/animation/effects/keyframe_applier.dart';
import 'package:fluvie/src/animation/effects/multi_keyframe_effect.dart';
import 'package:fluvie/src/animation/runtime/animation_plan_adapter.dart';
import 'package:fluvie/src/animation/runtime/keyframe_scope.dart';
import 'package:fluvie/src/animation/runtime/motion_runner.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/timing/placement/effective_duration.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/schedule/element_schedule.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// Builds one element's widget tree for one [frame] — the unified `Animation`
/// pipeline.
///
/// Per frame, every animation contributes at its own [MotionRunner.progress]
/// over its span from [schedule] (optionally shifted by [spanShifts], the
/// stagger pre-wiring — spans move, the window never does):
///
/// 1. **Keyframe-class** animations fold into a *single* composed [Keyframe]
///    (list order, last writer wins per field) applied by one render-safe
///    stack closest to [child]; a [KeyframeScope] around it publishes the
///    composed value for color-capable elements.
/// 2. **Transform-class** effects wrap outside it in list order (first in
///    the list is innermost).
/// 3. **Pixel-class** effects wrap outermost, in list order among
///    themselves, wherever they sat in the list.
///
/// Outside `[window.start, window.end)` the composed keyframe is forced to
/// opacity `0`, so the element keeps its layout slot but never paints.
///
/// [schedule] must align one span per animation, and a repeating animation
/// needs [schedule]'s defaults to be a fully merged cascade (its cycle length
/// comes from [effectiveDurationFrames]).
Widget buildAnimatedFrame({
  required Widget child,
  required List<Animation> animations,
  required ElementSchedule schedule,
  required TimeScopeData elementScope,
  required int frame,
  List<int>? spanShifts,
}) {
  assert(
    schedule.spans.length == animations.length,
    // coverage:ignore-start defensive assert message the resolver always aligns the counts
    'ElementSchedule carries ${schedule.spans.length} spans for '
    '${animations.length} animations — they must align index by index.',
    // coverage:ignore-end
  );
  assert(
    spanShifts == null || spanShifts.length == animations.length,
    'spanShifts must carry exactly one offset per animation.',
  );
  var composed = Keyframe.natural;
  final transforms = <(AnimationEffect, double)>[];
  final pixels = <(AnimationEffect, double)>[];
  for (var i = 0; i < animations.length; i++) {
    final animation = animations[i];
    final shift = spanShifts?[i] ?? 0;
    final base = schedule.spans[i];
    final span = shift == 0 ? base : ResolvedSpan(base.start + shift, base.end + shift);
    // Repeat is a `during` presentation concern; enter/exit keep their
    // one-cycle span and hold the endpoint, so extra cycles never render.
    final repeat = animation.phase == AnimationPhase.during ? animation.repeat : null;
    final cycleFrames = repeat == null ? 0 : _cycleFrames(animation, schedule, elementScope, span);
    final progress = MotionRunner.progress(
      frame: frame,
      span: span,
      ease: effectiveCurve(animation, schedule.defaults),
      spring: animation.spring,
      fps: elementScope.fps,
      repeat: repeat,
      cycleFrames: cycleFrames,
      gapFrames: repeat?.gap.resolveFrames(elementScope) ?? 0,
    );
    final effect = animation.effect;
    if (effectKindOf(effect) == EffectKind.pixel) {
      pixels.add((effect, progress));
    } else if (effect is KeyframeAnimationEffect) {
      composed = composed + _keyframeOf(effect, progress, span, cycleFrames, elementScope.fps);
    } else {
      transforms.add((effect, progress));
    }
  }
  final inWindow = frame >= schedule.window.start && frame < schedule.window.end;
  if (!inWindow) {
    composed = composed + Keyframe(opacity: 0, origin: composed.origin);
  }
  Widget result = KeyframeScope(keyframe: composed, child: applyKeyframe(composed, child));
  for (final (effect, progress) in transforms) {
    result = effect.build(result, progress);
  }
  for (final (effect, progress) in pixels) {
    result = effect.build(result, progress);
  }
  // The window rule covers pixel effects too: outside the window nothing may
  // paint, so the fully wrapped result (including pixel layers) is hidden with
  // its layout slot held.
  if (!inWindow && pixels.isNotEmpty) {
    result = applyKeyframe(const Keyframe(opacity: 0), result);
  }
  return result;
}

/// The frames over which one cycle of [animation]'s progress runs `0 → 1`:
/// the effective duration when it repeats (a `during` row's span is the
/// whole window, but it loops at its own duration), zero (unused) otherwise.
int _cycleFrames(
  Animation animation,
  ElementSchedule schedule,
  TimeScopeData elementScope,
  ResolvedSpan span,
) {
  if (animation.repeat == null) return 0;
  return effectiveDurationFrames(toAnimationPlan(animation), schedule.defaults, elementScope);
}

/// One keyframe-class contribution at [progress]; a [MultiKeyframeEffect]
/// with explicit `at:` times gets them resolved into stop fractions against
/// the frames its progress actually covers — one repeat cycle when looping,
/// the whole [span] otherwise.
Keyframe _keyframeOf(
  KeyframeAnimationEffect effect,
  double progress,
  ResolvedSpan span,
  int cycleFrames,
  int fps,
) {
  if (effect is MultiKeyframeEffect && effect.at != null) {
    final progressFrames = cycleFrames > 0 ? cycleFrames : span.end - span.start;
    if (progressFrames > 0) {
      final synthetic = TimeScopeData(fps: fps, startFrame: 0, durationFrames: progressFrames);
      final fractions = [
        for (final time in effect.at!) time.resolveFrames(synthetic) / progressFrames,
      ];
      return effect.keyframeAt(progress, stopFractions: fractions);
    }
  }
  return effect.keyframeAt(progress);
}
