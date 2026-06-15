import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:meta/meta.dart';

/// One resolved step in a `Timeline`'s placement plan: the
/// [animation] to play on [target], starting at the absolute [start].
///
/// A `Scene.sequence` binds each placement to the matching anchored child so
/// the timeline drives the elements. [start] is absolute (frames)
/// resolved against the timeline's fps, and [durationFrames] is the step's
/// resolved length, so the binder can place the animation with a fixed window.
@immutable
final class TimelinePlacement {
  /// Creates a placement of [animation] on [target] at [start], lasting
  /// [durationFrames] frames.
  const TimelinePlacement({
    required this.target,
    required this.animation,
    required this.start,
    required this.durationFrames,
  });

  /// The anchor naming the element this step animates; compared by identity.
  final Anchor target;

  /// The animation to play on [target] at [start].
  final Animation animation;

  /// The absolute start of the step within the timeline, as a frame [Time].
  final Time start;

  /// The step's resolved length in frames (the animation's effective duration).
  final int durationFrames;

  /// The absolute start frame — `start` resolved against the timeline's fps,
  /// which it already is (a `Time.frames`).
  int get startFrame => switch (start) {
    final FrameTime time => time.frames,
    _ => throw StateError('TimelinePlacement.start must be an absolute frame Time, got $start'),
  };

  @override
  String toString() =>
      'TimelinePlacement($target, $animation, start: $start, frames: $durationFrames)';
}
