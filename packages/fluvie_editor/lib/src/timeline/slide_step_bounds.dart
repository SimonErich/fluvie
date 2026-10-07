import 'package:fluvie/fluvie.dart' show introspectTimeline;
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/timeline/step_boundaries.dart';

/// The presenter-parity landing frames of one slide: the scene-relative
/// frame each click of a stepping presenter would come to rest on.
///
/// The ladder is the step markers' settle frames plus the slide's final
/// settle, mirrored from `compileSlidePlans` through [computeStepLayout]:
/// arriving lands on the first rung (the base step settled), each click
/// lands on the next, and past the last rung the next click leaves the
/// slide. Rungs collapse to a strictly increasing, positive sequence, so a
/// slide where nothing animates in yields no rungs at all.
List<int> slideStepBounds(EditorDocument document, int slide) {
  final scene = introspectTimeline(document.spec.build()).scenes[slide];
  final layout = computeStepLayout(
    topLevelIds: document.elementIdsInScene(slide),
    stepIds: sceneStepElementIds(document.sceneJson(slide)),
    childIdsOf: document.childIdsOfGroup,
    enterEndOf: (id) {
      final enter = scene.elementById(id)?.enterSpan;
      return enter == null ? null : enter.end - scene.span.start;
    },
  );
  var settle = 0;
  for (final end in layout.revealEnds.values) {
    if (end > settle) settle = end;
  }
  final bounds = <int>[];
  for (final frame in [...layout.markerFrames, settle]) {
    if (frame > (bounds.isEmpty ? 0 : bounds.last)) bounds.add(frame);
  }
  return List.unmodifiable(bounds);
}
