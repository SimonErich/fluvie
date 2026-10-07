part of 'slide_timeline_model.dart';

/// The step data of one slide: the layout (membership, reveal ends, marker
/// frames), the ruler markers, the stepped element ids (group children
/// included) whose bars can violate, and the live validation message.
final class _SlideSteps {
  const _SlideSteps({
    required this.layout,
    required this.markers,
    required this.steppedIds,
    required this.validationMessage,
  });

  /// Computes the slide's step data by mirroring the presenter's compiler:
  /// membership from the scene's `steps` list, settle frames from the
  /// introspected enter spans (the parity tests pin the mirror against
  /// `compileSlidePlans`), and the message from `validateStepPlan` — run
  /// synchronously, it is pure and fast, and it never throws, so markers
  /// stay laid out while a violation shows.
  factory _SlideSteps.compute(EditorDocument document, int slide, SceneIntrospection scene) {
    final stepIds = sceneStepElementIds(document.sceneJson(slide));
    final layout = computeStepLayout(
      topLevelIds: document.elementIdsInScene(slide),
      stepIds: stepIds,
      childIdsOf: document.childIdsOfGroup,
      enterEndOf: (id) {
        final enter = scene.elementById(id)?.enterSpan;
        return enter == null ? null : enter.end - scene.span.start;
      },
    );
    final errors = stepIds.isEmpty ? null : validateStepPlan(document.spec);
    return _SlideSteps(
      layout: layout,
      markers: List.unmodifiable([
        for (var k = 0; k < layout.markerFrames.length; k++)
          TimelineMarker(
            id: 'step:$k',
            frame: layout.markerFrames[k].toDouble(),
            label: '${k + 2}',
          ),
      ]),
      steppedIds: {
        for (final ids in stepIds)
          for (final id in ids) ...[id, ...document.childIdsOfGroup(id)],
      },
      validationMessage: (errors == null || errors.isEmpty) ? null : errors.first.message,
    );
  }

  final SlideStepLayout layout;
  final List<TimelineMarker> markers;
  final Set<String> steppedIds;
  final String? validationMessage;
}
