import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/runtime/animation_pipeline.dart';
import 'package:fluvie/src/animation/stagger/multi_child_rebuilder.dart';
import 'package:fluvie/src/animation/stagger/stagger_offsets.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/timing/schedule/element_schedule.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// Builds one element's widget tree for one [frame], distributing staggered
/// animations across a multi-child [child].
///
/// An animation staggers when it carries a [Stagger] or inherits one from the
/// merged `Defaults` cascade (`animation.stagger ?? schedule.defaults
/// .stagger`). Staggered animations apply *per direct child* of a supported
/// container (`Row`/`Column`/`Flex`, `Wrap`, `Stack`), each child's span
/// shifted by its [staggerOffsetFrames] offset — the spans move, the window
/// never does, and child 0's zero offset keeps the unshifted base span (the
/// chaining contract). Non-staggered animations in the same list keep
/// wrapping the container, so the container-level and child-level keyframe
/// compositions stay independent (keyframe composition applies at each level).
///
/// With no effective stagger, an unsupported container, or fewer than two
/// children, this is exactly [buildAnimatedFrame] — stagger on a single-child
/// target is ignored.
Widget buildStaggeredFrame({
  required Widget child,
  required List<Animation> animations,
  required ElementSchedule schedule,
  required TimeScopeData elementScope,
  required int frame,
}) {
  final staggers = [
    for (final animation in animations) animation.stagger ?? schedule.defaults.stagger,
  ];
  final staggeredIndices = [
    for (var i = 0; i < animations.length; i++)
      if (staggers[i] != null) i,
  ];
  final children = staggeredIndices.isEmpty ? null : wrappableChildrenOf(child);
  if (children == null || children.length < 2) {
    return buildAnimatedFrame(
      child: child,
      animations: animations,
      schedule: schedule,
      elementScope: elementScope,
      frame: frame,
    );
  }
  final offsetsByAnimation = [
    for (final i in staggeredIndices)
      staggerOffsetFrames(stagger: staggers[i]!, childCount: children.length, scope: elementScope),
  ];
  final staggeredAnimations = [for (final i in staggeredIndices) animations[i]];
  final staggeredSchedule = _subSchedule(schedule, staggeredIndices);
  // Non-null: wrappableChildrenOf and rebuildWithWrappedChildren dispatch on
  // the same container types, and children was non-null above.
  final rebuilt = rebuildWithWrappedChildren(
    child,
    (index, grandchild) => buildAnimatedFrame(
      child: grandchild,
      animations: staggeredAnimations,
      schedule: staggeredSchedule,
      elementScope: elementScope,
      frame: frame,
      spanShifts: [for (final offsets in offsetsByAnimation) offsets[index]],
    ),
  )!;
  final containerIndices = [
    for (var i = 0; i < animations.length; i++)
      if (staggers[i] == null) i,
  ];
  return buildAnimatedFrame(
    child: rebuilt,
    animations: [for (final i in containerIndices) animations[i]],
    schedule: _subSchedule(schedule, containerIndices),
    elementScope: elementScope,
    frame: frame,
  );
}

/// The schedule restricted to the animations at [indices], index-aligned with
/// the sub-list handed to [buildAnimatedFrame]; window and defaults carry
/// over untouched.
ElementSchedule _subSchedule(ElementSchedule schedule, List<int> indices) => ElementSchedule(
  window: schedule.window,
  spans: [for (final i in indices) schedule.spans[i]],
  defaults: schedule.defaults,
);
