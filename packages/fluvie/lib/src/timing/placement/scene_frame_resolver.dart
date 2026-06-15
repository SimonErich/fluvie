import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/timing/relative_duration_guard.dart';

/// Resolves one scene's [duration] to frames at [fps] — the single source of
/// scene-boundary math.
///
/// Both the composition resolver and the `Video` widget call this, so the
/// widget tree and the resolved plan can never disagree on where a scene
/// starts or ends. A relative [duration] (even hidden inside a composite) is
/// circular — a scene's length defines the window relative times measure
/// against — and throws a [FluvieTimingError] naming the scene by [sceneId].
int resolveSceneDurationFrames(Time duration, int fps, String sceneId) => duration.resolveFrames(
  RelativeDurationGuard(
    fps,
    "The duration of scene '$sceneId' cannot be relative: scene "
    'durations define the video length, so a relative duration would be '
    'a fraction of itself. Use frames, seconds, or ms for scene durations.',
  ),
);
