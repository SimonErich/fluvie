import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:meta/meta.dart';

/// Answers "relative to what does this animation start?"
///
/// A trigger is pure data — a description the resolver turns into a concrete
/// start frame by pattern-matching the subtype. Anchors referenced here are
/// compared by identity (see [Anchor]).
///
/// ```dart
/// final intro = Anchor('intro');
/// Text('Title').animate([Animation.pop()], anchor: intro);
/// Text('Sub').animate([Animation.fadeIn(at: Trigger.after(intro))]);
/// ```
@immutable
sealed class Trigger {
  /// Const base constructor shared by all variants.
  const Trigger();

  /// An absolute time [t] within the enclosing scene.
  const factory Trigger.at(Time t) = AbsoluteTrigger;

  /// Every [every]-th beat of the audio [track]'s analysed beat grid
  /// (`null` means the sole beat-tagged track).
  const factory Trigger.beat({int every, Anchor? track}) = BeatTrigger;

  /// The default: the element's own window edge (enter at its start, exit at
  /// its end).
  static const Trigger auto = AutoTrigger();

  /// The first frame of the enclosing scene.
  static const Trigger sceneStart = SceneStartTrigger();

  /// The last frame of the enclosing scene.
  static const Trigger sceneEnd = SceneEndTrigger();

  /// When the previous animation on **this** element settles (chaining).
  static const Trigger previous = PreviousTrigger();

  /// When [a]'s timeline **ends**.
  static Trigger after(Anchor a) => AfterTrigger(a);

  /// When [a]'s timeline **starts**.
  static Trigger whenStarts(Anchor a) => WhenStartsTrigger(a);
}

/// The [Trigger.auto] variant: the element's own window edge.
final class AutoTrigger extends Trigger {
  /// Value-equal to every other instance; [Trigger.auto] is the canonical one.
  const AutoTrigger();

  @override
  bool operator ==(Object other) => other is AutoTrigger;

  @override
  int get hashCode => (AutoTrigger).hashCode;

  @override
  String toString() => 'Trigger.auto';
}

/// The [Trigger.sceneStart] variant: the enclosing scene's first frame.
final class SceneStartTrigger extends Trigger {
  /// Value-equal to every other instance; [Trigger.sceneStart] is the canonical one.
  const SceneStartTrigger();

  @override
  bool operator ==(Object other) => other is SceneStartTrigger;

  @override
  int get hashCode => (SceneStartTrigger).hashCode;

  @override
  String toString() => 'Trigger.sceneStart';
}

/// The [Trigger.sceneEnd] variant: the enclosing scene's last frame.
final class SceneEndTrigger extends Trigger {
  /// Value-equal to every other instance; [Trigger.sceneEnd] is the canonical one.
  const SceneEndTrigger();

  @override
  bool operator ==(Object other) => other is SceneEndTrigger;

  @override
  int get hashCode => (SceneEndTrigger).hashCode;

  @override
  String toString() => 'Trigger.sceneEnd';
}

/// The [Trigger.previous] variant: chain after the previous animation on the
/// same element.
final class PreviousTrigger extends Trigger {
  /// Value-equal to every other instance; [Trigger.previous] is the canonical one.
  const PreviousTrigger();

  @override
  bool operator ==(Object other) => other is PreviousTrigger;

  @override
  int get hashCode => (PreviousTrigger).hashCode;

  @override
  String toString() => 'Trigger.previous';
}

/// The [Trigger.at] variant: an absolute [time] within the enclosing scene.
final class AbsoluteTrigger extends Trigger {
  /// Creates a trigger that fires at [time].
  const AbsoluteTrigger(this.time);

  /// When to start, resolved against the enclosing scene's scope.
  final Time time;

  @override
  bool operator ==(Object other) => other is AbsoluteTrigger && other.time == time;

  @override
  int get hashCode => Object.hash(AbsoluteTrigger, time);

  @override
  String toString() => 'Trigger.at($time)';
}

/// The [Trigger.beat] variant: fire on the audio track's beat grid.
final class BeatTrigger extends Trigger {
  /// Creates a trigger that fires every [every]-th beat of [track].
  const BeatTrigger({this.every = 1, this.track})
    : assert(every >= 1, 'BeatTrigger.every must be >= 1');

  /// Fire on every n-th beat; `1` (the default) is every beat.
  final int every;

  /// The anchor naming the audio track to follow, or `null` for the sole
  /// beat-tagged track. Compared by identity.
  final Anchor? track;

  @override
  bool operator ==(Object other) =>
      other is BeatTrigger && other.every == every && identical(other.track, track);

  @override
  int get hashCode => Object.hash(BeatTrigger, every, identityHashCode(track));

  @override
  String toString() => 'Trigger.beat(every: $every, track: $track)';
}

/// The [Trigger.after] variant: when [anchor]'s timeline ends.
final class AfterTrigger extends Trigger {
  /// Creates a trigger that fires when [anchor]'s timeline ends.
  const AfterTrigger(this.anchor);

  /// The anchored timeline to wait for; compared by identity.
  final Anchor anchor;

  @override
  bool operator ==(Object other) => other is AfterTrigger && identical(other.anchor, anchor);

  @override
  int get hashCode => Object.hash(AfterTrigger, identityHashCode(anchor));

  @override
  String toString() => 'Trigger.after($anchor)';
}

/// The [Trigger.whenStarts] variant: when [anchor]'s timeline starts.
final class WhenStartsTrigger extends Trigger {
  /// Creates a trigger that fires when [anchor]'s timeline starts.
  const WhenStartsTrigger(this.anchor);

  /// The anchored timeline to start with; compared by identity.
  final Anchor anchor;

  @override
  bool operator ==(Object other) => other is WhenStartsTrigger && identical(other.anchor, anchor);

  @override
  int get hashCode => Object.hash(WhenStartsTrigger, identityHashCode(anchor));

  @override
  String toString() => 'Trigger.whenStarts($anchor)';
}
