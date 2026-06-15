import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';

/// Carries the analysed [BeatGrid]s down to the `Video` so `Trigger.beat`
/// resolves against them in capture — the timing
/// counterpart to the media `ImageResolverScope`.
///
/// The capture shell analyses every reactive audio track once before frame 0
/// and mounts one of these above the composition: a [defaultBeatGrid] for the
/// sole beat-tagged track plus a per-[Anchor] map for `Trigger.beat(track: ...)`.
/// `VideoState._resolveSchedules` reads the nearest scope through [maybeOf] and
/// threads its grids into `buildVideoPlan`, so the grid arrives via context and
/// the authoring `Video(...)` surface stays unchanged.
///
/// A composition with no beat-tagged audio mounts no scope (or an [isEmpty]
/// one); `Trigger.beat` then resolves against no grid and throws the honest
/// `FluvieTimingError` the resolver already raises — the missing-scope state is
/// the correct neutral one.
final class BeatGridScope extends InheritedWidget {
  /// Provides the [defaultBeatGrid] (and optional per-anchor [trackBeatGrids])
  /// to every descendant of [child].
  const BeatGridScope({
    required this.defaultBeatGrid,
    required this.trackBeatGrids,
    required super.child,
    super.key,
  });

  /// The grid `Trigger.beat()` resolves against when no `track:` anchor is
  /// given — the sole beat-tagged track; `null` when there is none.
  final BeatGrid? defaultBeatGrid;

  /// Per-track grids keyed by the `Audio.track` anchor a `Trigger.beat(track:)`
  /// names. Compared by anchor identity.
  final Map<Anchor, BeatGrid> trackBeatGrids;

  /// Whether this scope carries no grid at all — the shell can skip mounting it.
  bool get isEmpty => defaultBeatGrid == null && trackBeatGrids.isEmpty;

  /// The nearest scope above [context], or `null` when there is none (a live
  /// preview, or a composition with no beat-tagged audio).
  static BeatGridScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BeatGridScope>();

  @override
  bool updateShouldNotify(BeatGridScope oldWidget) =>
      !identical(oldWidget.defaultBeatGrid, defaultBeatGrid) ||
      !_sameGrids(oldWidget.trackBeatGrids, trackBeatGrids);

  static bool _sameGrids(Map<Anchor, BeatGrid> a, Map<Anchor, BeatGrid> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!identical(b[entry.key], entry.value)) return false;
    }
    return true;
  }
}
