/// @docImport 'package:fluvie/src/animation/stagger/stagger_offsets.dart';
/// @docImport 'package:fluvie/src/core/stagger.dart';
/// @docImport 'package:fluvie/src/elements/counter.dart';
/// @docImport 'package:fluvie/src/elements/typewriter.dart';
library;

import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// The reveal progress at [frame] within [scope] for a [reveal] window.
///
/// This is the exact arithmetic [Counter] uses, promoted out of the chart family
/// so charts, `Typewriter`, `Code`, and `Terminal` share one reveal-math home:
/// the [reveal] [Time] resolves against [scope] (so `0.6.relative` measures the
/// element's own window for free), the elapsed frames since the scope began are
/// divided by the resolved reveal length, and the result is clamped to `[0, 1]`.
/// A zero- or negative-length reveal returns `1.0` (instantly revealed) instead
/// of dividing by zero.
///
/// One reveal-progress code path, shared by every reveal consumer, so none can
/// drift from [Counter].
double revealProgress(int frame, TimeScopeData scope, Time reveal) {
  final revealFrames = reveal.resolveFrames(scope);
  final elapsed = frame - scope.startFrame;
  return revealFrames <= 0 ? 1.0 : (elapsed / revealFrames).clamp(0.0, 1.0);
}

/// One clamped reveal progress per segment, each delayed by its stagger offset.
///
/// [elapsed] is the frames since the enclosing scope began; [offsets] is the
/// per-segment start delay from [staggerOffsetFrames] (the caller passes its
/// segment count as `childCount`); [perSegmentFrames] is each segment's reveal
/// length. Segment `i`'s progress is its offset subtracted from [elapsed],
/// divided by [perSegmentFrames], clamped to `0..1`, so a segment whose offset
/// has not yet passed reads `0` and a started segment with a zero-length span
/// reads `1`.
///
/// Returns one value per offset, in offset order — an empty list yields an
/// empty result. Pure frame arithmetic: identical inputs always return
/// identical progress.
List<double> staggeredRevealProgress({
  required int elapsed,
  required List<int> offsets,
  required int perSegmentFrames,
}) => [
  for (final offset in offsets)
    if (perSegmentFrames <= 0)
      (elapsed - offset >= 0) ? 1.0 : 0.0
    else
      ((elapsed - offset) / perSegmentFrames).clamp(0.0, 1.0),
];
