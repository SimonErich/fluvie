import 'dart:math' as math;

import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/stagger_origin.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// The default per-step gap of [Stagger.from] when none is given: 80 ms, the
/// recurring example gap.
const Time _defaultOriginGap = Time.ms(80);

/// One start offset (in frames) per child of a staggered multi-child target.
///
/// Offsets shift the staggered animation's *span* only — never the element's
/// window — and are derived per variant:
///
/// * [Stagger.each] — the gap resolves against [scope] **once** and child *i*
///   sits at `i × gapFrames`. Resolving `i × gap` per child would compound
///   rounding (0.08 s at 30 fps is 2.4 → `[0, 2, 5]`); the pinned rule keeps
///   the wave step exact: `[0, 2, 4]`.
/// * [Stagger.evenly] — `over` resolves once, then child *i* lands at
///   `round(i · overFrames / (n − 1))`, so the total feel stays constant as
///   children are added.
/// * [Stagger.from] — children are ordered from the origin with integer
///   ranks (`start`: `i`, `end`: `n − 1 − i`, `center`: `|2i − (n − 1)|`,
///   `edges`: `min(i, n − 1 − i)`); ties go to the lower index. The child's
///   offset is its wave position × the once-resolved gap (default 80 ms).
///
/// A single child gets the lone `[0]` (its span stays the base span); zero
/// children produce zero offsets. Pure frame arithmetic — identical inputs
/// always return identical offsets.
List<int> staggerOffsetFrames({
  required Stagger stagger,
  required int childCount,
  required TimeScopeData scope,
}) {
  if (childCount <= 0) return const [];
  return switch (stagger) {
    EachStagger(:final gap) => _multiples(gap.resolveFrames(scope), childCount),
    EvenlyStagger(:final over) => _evenly(over.resolveFrames(scope), childCount),
    OriginStagger(:final origin, :final gap) => _multiplesAt(
      _originPositions(origin, childCount),
      (gap ?? _defaultOriginGap).resolveFrames(scope),
    ),
  };
}

/// `[0, gap, 2·gap, …]` — the resolve-once-multiply rule for [Stagger.each].
List<int> _multiples(int gapFrames, int childCount) => [
  for (var i = 0; i < childCount; i++) i * gapFrames,
];

/// `round(i · over / (n − 1))` per child; one child collapses to `[0]`.
List<int> _evenly(int overFrames, int childCount) {
  if (childCount == 1) return const [0];
  return [for (var i = 0; i < childCount; i++) (i * overFrames / (childCount - 1)).round()];
}

/// Each child's wave position × the once-resolved [gapFrames].
List<int> _multiplesAt(List<int> positions, int gapFrames) => [
  for (final position in positions) position * gapFrames,
];

/// The origin order as one wave position per child index: ranks are pure
/// integer math, ties break toward the lower index, and the position is the
/// child's place in the sorted wave (`0` leads).
List<int> _originPositions(StaggerOrigin origin, int childCount) {
  final last = childCount - 1;
  final ranks = switch (origin) {
    StaggerOrigin.start => [for (var i = 0; i < childCount; i++) i],
    StaggerOrigin.end => [for (var i = 0; i < childCount; i++) last - i],
    StaggerOrigin.center => [for (var i = 0; i < childCount; i++) (2 * i - last).abs()],
    StaggerOrigin.edges => [for (var i = 0; i < childCount; i++) math.min(i, last - i)],
  };
  final order = [for (var i = 0; i < childCount; i++) i]
    ..sort((a, b) => ranks[a] == ranks[b] ? a.compareTo(b) : ranks[a].compareTo(ranks[b]));
  final positions = List<int>.filled(childCount, 0);
  for (var step = 0; step < childCount; step++) {
    positions[order[step]] = step;
  }
  return positions;
}
