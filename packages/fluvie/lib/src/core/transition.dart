import 'package:flutter/animation.dart' show Curve;
import 'package:flutter/painting.dart' show Alignment;
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:meta/meta.dart';

/// Which scene-to-scene blend a [Transition] performs.
enum TransitionKind {
  /// A hard cut: no blend window, the next scene simply starts.
  cut,

  /// A dissolve: the incoming scene fades in over the outgoing one.
  crossFade,

  /// A travelling reveal: the incoming scene is uncovered along an [Edge].
  wipe,

  /// The outgoing scene scales up and fades out, pushing *into* the cut.
  zoom,

  /// A push: the incoming scene slides in while the outgoing slides away.
  slide,
}

/// How two adjacent scenes blend at their boundary.
///
/// A transition is pure authoring data — one value class for every kind, with
/// the variant parameter non-null exactly for its own [kind]:
///
/// ```dart
/// Transition.cut()
/// Transition.crossFade(0.5.seconds, overlap: true)
/// Transition.wipe(0.4.seconds, direction: Edge.right)
/// Transition.zoom(0.6.seconds, into: Alignment.center)
/// Transition.slide(0.4.seconds, from: Edge.right)
/// ```
///
/// [overlap] controls timing: `true` means the two scenes share the blend
/// window and the total video shortens by [duration]; `false` means each
/// scene plays its full length and the blend overlays the incoming scene's
/// first frames while the outgoing is held at its final frame.
@immutable
final class Transition {
  /// A hard cut: zero [duration], no [overlap], no blend window at all.
  // coverage:ignore-line: const-ctor artifact, behavior pinned by transition_test
  const Transition.cut()
    : kind = TransitionKind.cut,
      duration = Time.zero,
      overlap = false,
      ease = Ease.linear,
      direction = null,
      into = null,
      from = null;

  /// A dissolve lasting [duration]: the incoming scene fades in over the
  /// outgoing one, with no dip to the background in between.
  const Transition.crossFade(this.duration, {this.overlap = true, this.ease = Ease.linear})
    : kind = TransitionKind.crossFade,
      direction = null,
      into = null,
      from = null;

  /// A reveal lasting [duration] whose front travels toward [direction]:
  /// `Edge.right` uncovers the incoming scene left-to-right.
  const Transition.wipe(
    this.duration, {
    this.direction = Edge.right,
    this.overlap = true,
    this.ease = Ease.linear,
  }) : kind = TransitionKind.wipe,
       into = null,
       from = null;

  /// A zoom lasting [duration]: the outgoing scene scales up anchored at
  /// [into] while fading out over the incoming one.
  const Transition.zoom(
    this.duration, {
    this.into = Alignment.center,
    this.overlap = true,
    this.ease = Ease.linear,
  }) : kind = TransitionKind.zoom,
       direction = null,
       from = null;

  /// A push lasting [duration]: the incoming scene slides in from the [from]
  /// edge while the outgoing slides off toward the opposite one.
  const Transition.slide(
    this.duration, {
    this.from = Edge.right,
    this.overlap = true,
    this.ease = Ease.linear,
  }) : kind = TransitionKind.slide,
       direction = null,
       into = null;

  /// Which blend this transition performs.
  final TransitionKind kind;

  /// How long the blend window lasts. Must be absolute (frames, seconds, or
  /// ms): a boundary sits between two scenes, so a relative duration is
  /// ambiguous and rejected at resolution time.
  final Time duration;

  /// Whether the two scenes share the blend window.
  ///
  /// `true` (the default on every timed kind) starts the incoming scene
  /// [duration] early, shortening the total video; `false` keeps every scene
  /// start unchanged and holds the outgoing scene at its final frame while
  /// the incoming blends in.
  final bool overlap;

  /// The easing applied to the blend progress; defaults to [Ease.linear] (a
  /// plain dissolve reads linear — opinionated motion is one parameter away).
  ///
  /// Equality on this field is identity: every [Ease] member is a const
  /// [Curve] singleton, so identity is value equality in practice.
  final Curve ease;

  /// The direction of travel of a [TransitionKind.wipe] front; `null` for
  /// every other kind.
  final Edge? direction;

  /// The anchor a [TransitionKind.zoom] scales into; `null` for every other
  /// kind.
  final Alignment? into;

  /// The edge a [TransitionKind.slide] pushes in from; `null` for every
  /// other kind.
  final Edge? from;

  @override
  bool operator ==(Object other) =>
      other is Transition &&
      other.kind == kind &&
      other.duration == duration &&
      other.overlap == overlap &&
      other.ease == ease &&
      other.direction == direction &&
      other.into == into &&
      other.from == from;

  @override
  int get hashCode => Object.hash(Transition, kind, duration, overlap, ease, direction, into, from);

  /// The factory-call form, omitting [ease]: curve singletons have no stable
  /// textual form, and identity equality makes one up unhelpful.
  @override
  String toString() => switch (kind) {
    TransitionKind.cut => 'Transition.cut()',
    TransitionKind.crossFade => 'Transition.crossFade($duration, overlap: $overlap)',
    TransitionKind.wipe => 'Transition.wipe($duration, direction: $direction, overlap: $overlap)',
    TransitionKind.zoom => 'Transition.zoom($duration, into: $into, overlap: $overlap)',
    TransitionKind.slide => 'Transition.slide($duration, from: $from, overlap: $overlap)',
  };
}
