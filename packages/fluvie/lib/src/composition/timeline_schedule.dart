/// @docImport 'package:fluvie/src/composition/scene.dart';
library;

import 'package:fluvie/src/core/time.dart';

/// What `Scene.sequence` needs from a beat-by-beat schedule: a total
/// [duration] the scene can adopt as its own.
///
/// This is the contract between scene composition and the `Timeline` authoring
/// surface: [Scene.sequence] consumes it (a `FakeTimeline` test fixture
/// satisfies it in tests), and `Timeline` implements it — no `Scene` change
/// required.
abstract interface class TimelineSchedule {
  /// The schedule's total length — the duration a sequence scene adopts.
  /// Must be absolute (frames, seconds, or ms), like every scene duration.
  Time get duration;
}
