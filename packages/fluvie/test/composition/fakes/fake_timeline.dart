import 'package:fluvie/src/composition/timeline_schedule.dart';
import 'package:fluvie/src/core/time.dart';

/// An in-memory [TimelineSchedule] with a fixed [duration].
///
/// Stands in for the real `Timeline` so `Scene.sequence` can be tested without
/// the authoring surface.
final class FakeTimeline implements TimelineSchedule {
  /// Creates a fake schedule lasting exactly [duration].
  FakeTimeline(this.duration);

  @override
  final Time duration;
}
