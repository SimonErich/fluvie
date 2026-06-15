/// @docImport 'package:fluvie/src/timing/timeline/debug_timeline.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/timing/timeline/resolved_timeline.dart';

/// The embedder-owned timeline egress: a listenable cell the enclosing `Video`
/// pushes its [ResolvedTimeline] into after every resolution.
///
/// Lessons return finished `Video` values, so a constructor callback cannot
/// exist and a descendant scope cannot be read from outside — instead the
/// embedder (inspector, tests) owns a probe, mounts a [TimelineProbeScope]
/// **above** the video, and listens. `null` until the first resolution
/// completes; render the value with [debugTimeline]. Zero cost when absent.
///
/// If resolution fails with a `FluvieTimingError` (e.g. `Trigger.beat` with no
/// analysed grid in preview mode) the `Video` calls [reportError] instead of
/// throwing up to the Flutter scheduler. Listeners fire in both cases, so the
/// embedder can show a structured error rather than a red debug banner.
final class TimelineProbe extends ValueNotifier<ResolvedTimeline?> {
  /// Creates an empty probe; `Video` fills it after its first resolution.
  TimelineProbe() : super(null);

  /// The error message from the most recent failed resolution, or `null` when
  /// the last resolution succeeded (or none has run yet).
  ///
  /// Set alongside a [notifyListeners] call by [reportError]; reset to `null`
  /// when [value] is assigned (a successful resolution clears any prior error).
  String? timingError;

  @override
  set value(ResolvedTimeline? newValue) {
    timingError = null;
    super.value = newValue;
  }

  /// Records a timing failure from the `Video`'s resolution pass and notifies
  /// listeners so the embedder can update.
  ///
  /// Called by `VideoState._resolveSchedules` on a caught `FluvieTimingError`.
  /// Resets automatically when a new probe is created for a new lesson.
  void reportError(String message) {
    timingError = message;
    notifyListeners();
  }
}

/// Mounts a [TimelineProbe] above a `Video` so the video can push its
/// resolved timeline up to the embedder.
final class TimelineProbeScope extends InheritedWidget {
  /// Exposes [probe] to the `Video` inside [child].
  const TimelineProbeScope({required this.probe, required super.child, super.key});

  /// The embedder's probe; `Video` assigns its timeline to `probe.value`.
  final TimelineProbe probe;

  /// The nearest probe above [context], or `null` when no embedder mounted
  /// one — the signal to skip pushing entirely.
  ///
  /// A dependency-free lookup (not `dependOnInheritedWidgetOfExactType`):
  /// `Video` reads it from a post-frame callback, and change notification
  /// already flows through the probe's own listenable.
  static TimelineProbe? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TimelineProbeScope>()?.probe;

  @override
  bool updateShouldNotify(TimelineProbeScope oldWidget) => !identical(oldWidget.probe, probe);
}
