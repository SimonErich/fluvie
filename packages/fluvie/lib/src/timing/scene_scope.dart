import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';
import 'package:fluvie/src/timing/video_scope.dart';

/// Mounts a scene's [TimeScopeProvider] inside the enclosing [VideoScope].
///
/// Resolves [duration] and [start] against the *parent* scope (so a relative
/// scene duration means a fraction of the video) and injects a child scope at
/// the running offset. This is the timing shell the `Scene` widget wraps
/// around its content.
final class SceneScope extends StatelessWidget {
  /// Creates a scene scope lasting [duration], beginning [start] into the
  /// parent scope (default: its first frame), above [child].
  const SceneScope({
    required this.duration,
    required this.child,
    this.start = Time.zero,
    super.key,
  });

  /// How long the scene lasts; resolved against the parent scope.
  final Time duration;

  /// Where the scene begins within the parent scope — the running offset of
  /// the scenes before it. Resolved against the parent scope.
  final Time start;

  /// The scene's content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final parent = TimeScopeProvider.maybeOf(context);
    if (parent == null) {
      throw FluvieTimingError(
        'SceneScope found no enclosing VideoScope. A scene can only resolve its '
        'duration inside the root scope — wrap the tree in a VideoScope (or Video).',
      );
    }
    return TimeScopeProvider(
      scope: parent.child(
        startFrame: parent.startFrame + start.resolveFrames(parent),
        durationFrames: duration.resolveFrames(parent),
      ),
      child: child,
    );
  }
}
