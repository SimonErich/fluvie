import 'package:fluvie_editor/src/video_mode/video_lane_bindings.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_model.dart';

/// One element bar: the id the timeline calls it and what it joins back to.
typedef VideoLaneBar = ({String barId, VideoElementLaneBinding binding});

/// Every element bar in [scene], earliest window first.
///
/// Ordered so a verb that walks the slide — a ripple closing a gap — reads it
/// the way the eye does, left to right, rather than in document order.
List<VideoLaneBar> sceneElementBars(VideoLaneModel model, int scene) {
  return [
    for (final entry in model.elementBars.entries)
      if (entry.value.scene == scene) (barId: entry.key, binding: entry.value),
  ]..sort((a, b) => a.binding.window.start.compareTo(b.binding.window.start));
}

/// The bars in [scene] whose window ends exactly at [frame], never counting
/// [except].
///
/// A list rather than one answer, because "the clip before this one" is only
/// a single clip when exactly one ends there. Two of them is not a cut a roll
/// or a slide can move, and picking one would move footage the author never
/// pointed at.
List<VideoLaneBar> barsEndingAt(
  VideoLaneModel model,
  int scene,
  int frame, {
  required String except,
}) => [
  for (final bar in sceneElementBars(model, scene))
    if (bar.barId != except && bar.binding.window.end == frame) bar,
];

/// The bars in [scene] whose window starts exactly at [frame], never counting
/// [except].
List<VideoLaneBar> barsStartingAt(
  VideoLaneModel model,
  int scene,
  int frame, {
  required String except,
}) => [
  for (final bar in sceneElementBars(model, scene))
    if (bar.barId != except && bar.binding.window.start == frame) bar,
];
