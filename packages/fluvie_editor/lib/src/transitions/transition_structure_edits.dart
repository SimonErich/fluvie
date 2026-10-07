import 'package:fluvie/fluvie.dart' show introspectTimeline;
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/video_mode/video_element_owner.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_model.dart';
import 'package:fluvie_editor/src/video_mode/video_mode_edits.dart';

/// Materializes derived transition windows before an edit changes the chain's
/// topology. Already-overlapping windows are legal and resolve identically.
/// This keeps detached halves on their rendered frames after a razor cut.
Map<String, Object?> transitionSceneForEdit(
  VideoLaneModel model,
  int scene, {
  bool abutting = false,
}) {
  final document = model.document;
  final json = document.sceneJson(scene);
  final timeline = introspectTimeline(document.spec.build());
  for (final entry in model.elementBars.entries) {
    final binding = entry.value;
    if (binding.scene != scene || !model.hasClipTransition(entry.key)) continue;
    final origin = videoElementOwner(document, timeline, binding.elementId).start;
    final element = _find(json['children']! as List<Object?>, binding.elementId)!;
    element['show'] = {
      'from': '${binding.window.start - origin}f',
      'to': '${binding.window.end - origin}f',
    };
  }
  if (abutting) {
    final edges = model.document.spec.scenes[scene].transitions;
    final outgoing = {for (final edge in edges) edge.outgoing: edge};
    final incoming = {for (final edge in edges) edge.incoming};
    for (final root in outgoing.keys.where((id) => !incoming.contains(id))) {
      var id = root;
      while (outgoing.containsKey(id)) {
        final edge = outgoing[id]!;
        final from = _find(json['children']! as List<Object?>, id)!;
        final to = _find(json['children']! as List<Object?>, edge.incoming)!;
        final fromShow = from['show']! as Map<String, Object?>;
        final toShow = to['show']! as Map<String, Object?>;
        int frame(Object? value) => int.parse((value! as String).replaceAll('f', ''));
        final start = frame(fromShow['to']);
        final length = frame(toShow['to']) - frame(toShow['from']);
        to['show'] = {'from': '${start}f', 'to': '${start + length}f'};
        id = edge.incoming;
      }
    }
  }
  return json;
}

/// Changes a paired clip only when the resulting transition remains valid and
/// the rendered bar actually reaches the requested bounds.
VideoLaneEdit transitionClipWindowEdited(
  VideoLaneModel model,
  String barId,
  int start,
  int end, {
  String? mergeGroup,
}) {
  final binding = model.elementBars[barId]!;
  final document = model.document;
  final json = transitionSceneForEdit(model, binding.scene);
  final origin = videoElementOwner(
    document,
    introspectTimeline(document.spec.build()),
    binding.elementId,
  ).start;
  _find(json['children']! as List<Object?>, binding.elementId)!['show'] = {
    'from': '${start - origin}f',
    'to': '${end - origin}f',
  };
  final command = UpdateSceneCommand(
    index: binding.scene,
    patch: {'children': json['children']},
    mergeGroup: mergeGroup,
  );
  try {
    final result = VideoLaneModel.build(document: command.apply(document));
    final window = result.elementBars[barId]?.window;
    if (window == null || window.start != start || window.end != end) {
      return const VideoLaneEdit.refused(
        'The transition anchors this edge to its neighbouring cut. Move the cut or change the transition duration.',
      );
    }
    return VideoLaneEdit.command(command);
  } on Object catch (error) {
    return VideoLaneEdit.refused('The edit would invalidate the clip transition: $error');
  }
}

/// Splits a paired clip and transfers its outgoing transition to the new tail.
/// The incoming transition stays on the head. One scene patch validates both
/// changes atomically, preserving group and element paint order.
VideoLaneEdit transitionClipRazored(
  VideoLaneModel model,
  String id,
  String tailId,
  Map<String, Object?> head,
  Map<String, Object?> tail, {
  String? mergeGroup,
}) {
  final binding = model.elementBars['el:$id']!;
  final json = transitionSceneForEdit(model, binding.scene);
  final holding = _holding(json['children']! as List<Object?>, id)!;
  final index = holding.indexWhere((child) => (child! as Map<String, Object?>)['id'] == id);
  holding[index] = {...head, 'id': id};
  holding.insert(index + 1, {...tail, 'id': tailId});
  for (final edge in json['transitions']! as List<Object?>) {
    final pair = (edge! as Map<String, Object?>)['between']! as List<Object?>;
    if (pair.first == id) pair[0] = tailId;
  }
  final command = UpdateSceneCommand(
    index: binding.scene,
    patch: {'children': json['children'], 'transitions': json['transitions']},
    mergeGroup: mergeGroup,
  );
  try {
    command.apply(model.document);
    return VideoLaneEdit.command(command);
  } on Object catch (error) {
    return VideoLaneEdit.refused(
      'The razor cut leaves insufficient material for the clip transition: $error',
    );
  }
}

Map<String, Object?>? _find(List<Object?> children, String id) {
  final holding = _holding(children, id);
  return holding?.firstWhere((child) => (child! as Map<String, Object?>)['id'] == id)
      as Map<String, Object?>?;
}

List<Object?>? _holding(List<Object?> children, String id) {
  for (final child in children.cast<Map<String, Object?>>()) {
    if (child['id'] == id) return children;
    if (child['children'] case final List<Object?> nested) {
      final found = _holding(nested, id);
      if (found != null) return found;
    }
  }
  return null;
}
