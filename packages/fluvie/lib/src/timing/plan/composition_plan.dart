import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/timing/plan/scene_plan.dart';
import 'package:meta/meta.dart';

/// The root of the plan model: everything the timing resolver needs to turn
/// a whole composition into absolute frame spans, with no widgets attached.
///
/// `resolveComposition` is a pure function of this value — same plan in, same
/// timeline out — which is what makes timing resolution testable without
/// pumping a widget tree and deterministic by construction.
@immutable
final class CompositionPlan {
  /// Creates the plan for a whole composition; [fps] and [scenes] are
  /// required.
  const CompositionPlan({
    required this.fps,
    required this.scenes,
    this.transitions = const [],
    this.defaults,
    this.themeDefaults,
    this.defaultBeatGrid,
    this.trackBeatGrids = const {},
  });

  /// Frames per second of the whole render.
  final int fps;

  /// The scenes in playback order; total duration is their sum minus the
  /// overlapping transition windows.
  final List<ScenePlan> scenes;

  /// The boundary transitions, one per adjacent scene pair (`null` = cut);
  /// the empty default means all-cut and resolves byte-identically to a plan
  /// with no transitions at all. Any other length than
  /// `scenes.length - 1` is rejected by `resolveSceneOffsets`.
  final List<Transition?> transitions;

  /// Video-level defaults, or `null` for the package defaults alone.
  final Defaults? defaults;

  /// The `FluvieTheme.motion` cascade layer — below [defaults] and above the
  /// package default; `null` leaves the cascade byte-identical.
  final Defaults? themeDefaults;

  /// The beat grid `Trigger.beat()` resolves against when no `track:` anchor
  /// is given — the sole beat-tagged track; `null` when there is none, which
  /// is an error at resolution time.
  final BeatGrid? defaultBeatGrid;

  /// Beat grids per audio-track anchor, for `Trigger.beat(track: ...)`.
  /// Keyed by anchor identity.
  final Map<Anchor, BeatGrid> trackBeatGrids;

  @override
  String toString() =>
      'CompositionPlan(fps: $fps, scenes: ${scenes.length}, '
      'transitions: ${transitions.length}, defaults: $defaults, '
      'defaultBeatGrid: $defaultBeatGrid, trackBeatGrids: ${trackBeatGrids.length})';
}
