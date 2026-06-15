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
/// A child with no anchor, or an anchor the timeline never played, passes
/// through untouched — so an author can still hand-animate elements the
/// timeline does not own. An empty timeline returns [children] verbatim.
List<Widget> bindTimeline(Timeline timeline, List<Widget> children) {
  final placements = timeline.placements;
  if (placements.isEmpty) return children;
  final byAnchor = <Anchor, List<TimelinePlacement>>{};
  for (final placement in placements) {
    (byAnchor[placement.target] ??= []).add(placement);
  }
  return [for (final child in children) _bindChild(child, byAnchor)];
}

/// Rebinds one [child] when it is an anchored [MotionTarget] the timeline owns;
/// otherwise returns it unchanged.
Widget _bindChild(Widget child, Map<Anchor, List<TimelinePlacement>> byAnchor) {
  if (child is! MotionTarget) return child;
  final anchor = child.anchor;
  if (anchor == null) return child;
  final placements = byAnchor[anchor];
  if (placements == null) return child;
  return child.child.animate(
    [for (final placement in placements) _placed(placement)],
    anchor: anchor,
    window: child.window,
    defaults: child.defaults,
  );
}

/// The placement's animation repositioned to start at its absolute frame.
///
/// Rebuilds the animation through [Animation.custom] so the effect, phase, and
/// timing carry over verbatim while [Animation.at] becomes a [Trigger.at] at
/// the resolved start (the rest of the timing tail is preserved too).
Animation _placed(TimelinePlacement placement) {
  final source = placement.animation;
  return Animation.custom(
    source.effect,
    phase: source.phase,
    duration: source.duration,
    ease: source.ease,
    spring: source.spring,
    delay: source.delay,
    at: Trigger.at(Time.frames(placement.startFrame)),
    stagger: source.stagger,
    repeat: source.repeat,
    label: source.label,
  );
}
