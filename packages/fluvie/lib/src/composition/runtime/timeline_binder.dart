import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/composition/timeline.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/trigger.dart';

/// Binds [timeline]'s placement plan onto [children] so the timeline drives the
/// scene's anchored elements.
///
/// A `Scene.sequence` writes its children as bare anchored targets
/// (`Text('Title').animate(const [], anchor: title)`) and lets the [Timeline]
/// supply the motion: for each child that is a [MotionTarget] whose anchor the
/// timeline played, this replaces the child's animations with the timeline's,
/// each repositioned to its resolved absolute start via [Trigger.at] (the
/// element window stays the whole scene, so the placement frame is the start).
/// Binding happens at construction, before any fps is known, so each start is
/// a scope-computed [Time] that resolves the plan at the enclosing `Video`'s
/// fps. A child with no anchor, or an anchor the timeline never played, passes
/// through untouched — so an author can still hand-animate elements the
/// timeline does not own. An empty timeline returns [children] verbatim.
List<Widget> bindTimeline(Timeline timeline, List<Widget> children) {
  final refs = timeline.placementRefs;
  if (refs.isEmpty) return children;
  final byAnchor = <Anchor, List<Animation>>{};
  for (var index = 0; index < refs.length; index++) {
    final ref = refs[index];
    (byAnchor[ref.target] ??= []).add(_placed(timeline, ref.animation, index));
  }
  return [for (final child in children) _bindChild(child, byAnchor)];
}

/// Rebinds one [child] when it is an anchored [MotionTarget] the timeline owns;
/// otherwise returns it unchanged.
Widget _bindChild(Widget child, Map<Anchor, List<Animation>> byAnchor) {
  if (child is! MotionTarget) return child;
  final anchor = child.anchor;
  if (anchor == null) return child;
  final animations = byAnchor[anchor];
  if (animations == null) return child;
  return child.child.animate(
    animations,
    anchor: anchor,
    window: child.window,
    defaults: child.defaults,
  );
}

/// The placement's animation repositioned to start at its resolved frame.
///
/// Rebuilds the animation through [Animation.custom] so the effect, phase, and
/// timing carry over verbatim while [Animation.at] becomes a [Trigger.at]
/// whose time resolves the plan at the consuming scope's fps (the rest of the
/// timing tail is preserved too).
Animation _placed(Timeline timeline, Animation source, int index) => Animation.custom(
  source.effect,
  phase: source.phase,
  duration: source.duration,
  ease: source.ease,
  spring: source.spring,
  delay: source.delay,
  at: Trigger.at(ComputedTime((scope) => timeline.startFrameAt(scope.fps, index))),
  stagger: source.stagger,
  repeat: source.repeat,
  label: source.label,
);
