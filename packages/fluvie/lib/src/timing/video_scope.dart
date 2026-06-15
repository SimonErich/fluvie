/// @docImport 'package:fluvie/src/timing/scene_scope.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/timing/relative_duration_guard.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// Mounts the root [TimeScopeData]: frame `0`, the video's [fps], and its
/// resolved [duration].
///
/// This is the timing shell the `Video` widget wraps around its scenes;
/// [SceneScope] nests inside it. [duration] must be absolute
/// (frames, seconds, or ms) — a relative duration at the root is circular
/// ("half of itself") and throws a [FluvieTimingError].
final class VideoScope extends StatelessWidget {
  /// Creates the root scope at [fps] lasting [duration], above [child].
  const VideoScope({required this.fps, required this.duration, required this.child, super.key});

  /// Frames per second of the whole render.
  final int fps;

  /// Total length of the video; must not contain a relative component.
  final Time duration;

  /// The subtree (typically the scenes) living inside this scope.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final durationFrames = duration.resolveFrames(
      RelativeDurationGuard(
        fps,
        'The video duration cannot be relative: at the root there is no '
        'enclosing window yet, so a relative duration would be a fraction of '
        'itself. Use frames, seconds, or ms for the video duration.',
      ),
    );
    return TimeScopeProvider(
      scope: TimeScopeData(fps: fps, startFrame: 0, durationFrames: durationFrames),
      child: child,
    );
  }
}
