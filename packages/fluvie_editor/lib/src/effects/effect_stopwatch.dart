import 'package:fluvie/fluvie.dart' show KeyframedNumber, introspectTimeline;
import 'package:fluvie_editor/src/document/editor_document.dart';

/// The keyframed form the stopwatch turns a literal [value] into: a flat
/// two-stop ramp over element [id]'s own window, so the picture at every
/// frame is exactly what it was and the only change is the diamonds
/// appearing on the timeline.
Map<String, Object?> stopwatchRampFor(EditorDocument document, String id, double value) => {
  'values': [value, value],
  'positions': ['0f', '${elementWindowFramesOf(document, id)}f'],
};

/// The literal the stopwatch collapses a keyframed [param] back to: the
/// value the ramp reads at the playhead against element [id]'s own window —
/// the same span the render resolves the ramp against, so what you see is
/// what you keep. With no playhead to read at, it is the ramp's first value.
double stopwatchLiteralFor(
  EditorDocument document,
  String id,
  Map<String, Object?> param, {
  double? progress,
}) {
  final ramp = KeyframedNumber.maybeFromJson(param);
  if (ramp == null) return 0;
  final frames = elementWindowFramesOf(document, id);
  if (progress == null || frames <= 0) return ramp.values.first;
  return ramp.at((progress: progress, fps: document.spec.fps, windowFrames: frames));
}

/// How many frames element [id] is alive for: the introspected alive-window
/// for a windowed element, its whole scene for a bare one (which has no
/// timeline presence of its own to introspect), and the whole video for an
/// overlay — exactly the span the render resolves the element's keyframed
/// parameters against.
int elementWindowFramesOf(EditorDocument document, String id) {
  final introspection = introspectTimeline(document.spec.build());
  for (final scene in introspection.scenes) {
    final element = scene.elementById(id);
    if (element != null) return element.window.durationFrames;
    final ids = document.elementIdsInScene(scene.index);
    if (ids.contains(id) || ids.any((groupId) => document.childIdsOfGroup(groupId).contains(id))) {
      return scene.span.durationFrames;
    }
  }
  return introspection.totalFrames;
}
