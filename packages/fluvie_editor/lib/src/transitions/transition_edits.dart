import 'package:fluvie/fluvie.dart' show ElementTransitionSpec, FrameSpan;
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/transitions/transition_structure_edits.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_model.dart';
import 'package:fluvie_editor/src/video_mode/video_mode_edits.dart';

/// A transition dragged from the browser onto a clip cut.
final class TransitionDragData {
  /// Uses a half-second duration unless [durationFrames] is specified.
  const TransitionDragData(this.kind, {this.durationFrames});

  /// Registered strategy name.
  final String kind;

  /// An explicit duration, or null for the browser default.
  final int? durationFrames;
}

/// A transition bar's document identity and resolved whole-video window.
final class VideoTransitionBinding {
  /// Identifies a transition within its owning scene.
  const VideoTransitionBinding({
    required this.scene,
    required this.index,
    required this.spec,
    required this.window,
    this.locked = false,
  });

  /// Owning scene index.
  final int scene;

  /// Position in that scene's transition list.
  final int index;

  /// Authored transition specification.
  final ElementTransitionSpec spec;

  /// Visible blend, on the whole-video ruler.
  final FrameSpan window;

  /// The paired lane is locked.
  final bool locked;
}

/// Places a strategy at the closest valid cut on [row], within half a second.
/// All model validation runs before a command can enter undo history.
VideoLaneEdit transitionDropped(
  EditorDocument document,
  VideoLaneModel model,
  String row,
  double frame,
  TransitionDragData data,
) {
  final track = model.tracks.where((track) => track.id == row).firstOrNull;
  if (track?.locked ?? false) {
    return const VideoLaneEdit.refused('Unlock the lane before adding a transition.');
  }
  final clips =
      model.elementBars.entries
          .where(
            (entry) =>
                model.rowOf(entry.key) == row &&
                document.elementJson(entry.value.elementId)?['type'] == 'Clip' &&
                entry.value.members.isEmpty,
          )
          .map((entry) => entry.value)
          .toList()
        ..sort((a, b) => a.window.start.compareTo(b.window.start));
  ({int scene, String a, String b, double distance})? nearest;
  for (var i = 1; i < clips.length; i++) {
    final a = clips[i - 1];
    final b = clips[i];
    if (a.scene != b.scene ||
        document.parentGroupOf(a.elementId) != document.parentGroupOf(b.elementId)) {
      continue;
    }
    final distance = (frame - a.window.end).abs();
    if (distance > model.fps / 2 || (nearest != null && distance >= nearest.distance)) continue;
    if (b.window.start > a.window.end) continue;
    nearest = (scene: a.scene, a: a.elementId, b: b.elementId, distance: distance);
  }
  if (nearest == null) {
    return const VideoLaneEdit.refused('Drop near a cut between adjacent clips on one lane.');
  }
  final scene = nearest.scene;
  final transitions = [for (final edge in document.spec.scenes[scene].transitions) edge.toJson()]
    ..removeWhere(
      (edge) =>
          (edge['between']! as List).first == nearest!.a &&
          (edge['between']! as List).last == nearest.b,
    )
    ..add({
      'between': [nearest.a, nearest.b],
      'kind': data.kind,
      'duration': '${data.durationFrames ?? (model.fps / 2).round()}f',
      if (data.kind == 'wipe') 'direction': 'left',
      if (data.kind == 'slide') 'from': 'right',
    });
  return _validated(
    document,
    UpdateSceneCommand(index: scene, patch: {'transitions': transitions}),
  );
}

/// Retimes a blend from either edge without truncating a duration that does not
/// fit. The pair's audio envelopes derive from the same persisted duration.
VideoLaneEdit transitionResized(
  EditorDocument document,
  VideoTransitionBinding binding,
  double start,
  double end, {
  String? mergeGroup,
}) {
  if (binding.locked) {
    return const VideoLaneEdit.refused('Unlock the lane before editing its transition.');
  }
  final frames = (end - start).round();
  if (frames < 1) return const VideoLaneEdit.refused('A transition needs at least one frame.');
  final transitions = [
    for (final edge in document.spec.scenes[binding.scene].transitions) edge.toJson(),
  ];
  transitions[binding.index] = {...transitions[binding.index], 'duration': '${frames}f'};
  return _validated(
    document,
    UpdateSceneCommand(
      index: binding.scene,
      patch: {
        'transitions': transitions,
        'children': transitionSceneForEdit(
          VideoLaneModel.build(document: document),
          binding.scene,
          abutting: true,
        )['children'],
      },
      mergeGroup: mergeGroup,
    ),
  );
}

/// Removes a selected transition, leaving its original clip windows intact.
VideoLaneEdit transitionRemoved(EditorDocument document, VideoTransitionBinding binding) {
  if (binding.locked) {
    return const VideoLaneEdit.refused('Unlock the lane before deleting its transition.');
  }
  final transitions = [
    for (final edge in document.spec.scenes[binding.scene].transitions) edge.toJson(),
  ]..removeAt(binding.index);
  return _validated(
    document,
    UpdateSceneCommand(
      index: binding.scene,
      patch: {'transitions': transitions.isEmpty ? null : transitions},
    ),
  );
}

VideoLaneEdit _validated(EditorDocument document, EditorCommand command) {
  try {
    command.apply(document);
    return VideoLaneEdit.command(command);
  } on Object catch (error) {
    return VideoLaneEdit.refused('Transition refused: $error');
  }
}
