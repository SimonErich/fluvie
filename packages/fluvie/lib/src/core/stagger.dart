import 'package:fluvie/src/core/stagger_origin.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:meta/meta.dart';

/// How one animation distributes start offsets across a multi-child target.
///
/// Put it on the container's `.animate()` — each child plays the same
/// animation, offset by the stagger:
///
/// ```dart
/// Column(children: [Text('A'), Text('B'), Text('C')])
///     .animate([Animation.slideFadeIn(stagger: Stagger.each(0.08.seconds))]);
/// ```
///
/// A stagger is pure data; the distribution math (per-child offsets, origin
/// ordering) runs in the timing resolver and animation system (Phases 3/5).
@immutable
sealed class Stagger {
  /// Const base constructor shared by all variants.
  const Stagger();

  /// A fixed [gap] between consecutive children: child *n* starts `n × gap`
  /// after the first.
  const factory Stagger.each(Time gap) = EachStagger;

  /// Spreads all children evenly across the [over] span, whatever their
  /// count — the total feel stays constant as children are added.
  const factory Stagger.evenly({required Time over}) = EvenlyStagger;

  /// Staggers outward from [origin] — center-out, edges-in, or from either
  /// end. The optional [gap] is the per-step offset; `null` lets the
  /// resolver pick a per-child default.
  const factory Stagger.from(StaggerOrigin origin, {Time? gap}) = OriginStagger;
}

/// The [Stagger.each] variant: a fixed gap between consecutive children.
final class EachStagger extends Stagger {
  /// Creates a stagger of [gap] between consecutive children.
  const EachStagger(this.gap);

  /// The offset added per child, in document order.
  final Time gap;

  @override
  bool operator ==(Object other) => other is EachStagger && other.gap == gap;

  @override
  int get hashCode => Object.hash(EachStagger, gap);

  @override
  String toString() => 'Stagger.each($gap)';
}

/// The [Stagger.evenly] variant: children share one fixed span.
final class EvenlyStagger extends Stagger {
  /// Creates a stagger that spreads all children evenly across [over].
  const EvenlyStagger({required this.over});

  /// The total span the children's start offsets are distributed across.
  final Time over;

  @override
  bool operator ==(Object other) => other is EvenlyStagger && other.over == over;

  @override
  int get hashCode => Object.hash(EvenlyStagger, over);

  @override
  String toString() => 'Stagger.evenly(over: $over)';
}

/// The [Stagger.from] variant: the wave starts at a [StaggerOrigin].
final class OriginStagger extends Stagger {
  /// Creates a stagger ordered from [origin], optionally stepping by [gap].
  const OriginStagger(this.origin, {this.gap});

  /// Where the wave starts among the children.
  final StaggerOrigin origin;

  /// The per-step offset; `null` means the resolver picks a per-child
  /// default when distributing (Phases 3/5).
  final Time? gap;

  @override
  bool operator ==(Object other) =>
      other is OriginStagger && other.origin == origin && other.gap == gap;

  @override
  int get hashCode => Object.hash(OriginStagger, origin, gap);

  @override
  String toString() => gap == null ? 'Stagger.from($origin)' : 'Stagger.from($origin, gap: $gap)';
}
