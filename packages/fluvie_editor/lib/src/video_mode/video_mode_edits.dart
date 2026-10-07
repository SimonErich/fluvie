import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/transitions/transition_structure_edits.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_bindings.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_model.dart';
import 'package:meta/meta.dart';

part 'video_mode_audio_edits.dart';

part 'video_mode_element_edits.part.dart';
part 'video_mode_window_edits.part.dart';

/// The outcome of one video-timeline lane gesture: the command to dispatch,
/// the note explaining a refusal or a clamp, or both (a drag that clamped
/// against a scene boundary still writes the clamped window).
@immutable
final class VideoLaneEdit {
  /// A clean edit: [command] and no note.
  const VideoLaneEdit.command(EditorCommand this.command) : note = null;

  /// A refused edit: no command, [note] says why.
  const VideoLaneEdit.refused(String this.note) : command = null;

  /// A clamped edit: [command] writes what fit, [note] says what did not.
  const VideoLaneEdit.clamped(EditorCommand this.command, String this.note);

  /// The command to dispatch, or null when the gesture was refused.
  final EditorCommand? command;

  /// The honest explanation of a refusal or clamp, or null for a clean
  /// edit.
  final String? note;
}

/// Maps a lane-bar body drag to its document edit: an element move shifts
/// its `show` window (scene-relative, clamped to the scene), a bar whose
/// new start lands in another scene moves the element there (the window
/// rewrites to keep the bar exactly where it was dropped), and a
/// time-placed sfx move rewrites its `at` time. Returns null for a no-op
/// (scene blocks, unknown bars, motionless drags).
VideoLaneEdit? videoBarMoved(
  VideoLaneModel model,
  String barId,
  double newStart, {
  String? mergeGroup,
}) {
  if (model.isLocked(barId)) {
    return const VideoLaneEdit.refused('Unlock the lane before editing it.');
  }
  if (model.hasClipTransition(barId)) {
    final current = model.elementBars[barId]!.window;
    return transitionClipWindowEdited(
      model,
      barId,
      newStart.round(),
      newStart.round() + current.durationFrames,
      mergeGroup: mergeGroup,
    );
  }
  final overlay = model.overlayBars[barId];
  if (overlay != null) {
    final start = newStart.round().clamp(0, model.totalFrames - overlay.window.durationFrames);
    return _globalWindow(overlay, start, start + overlay.window.durationFrames, mergeGroup);
  }
  final element = model.elementBars[barId];
  if (element != null && element.members.isNotEmpty) {
    final delta = newStart.round() - element.window.start;
    return _sharedWindow(element, delta, delta, mergeGroup, moving: true);
  }
  if (element != null) return _elementMoved(model, element, newStart, mergeGroup);
  final audio = model.audioBars[barId];
  if (audio != null) return _audioMoved(model, audio, newStart, mergeGroup);
  return null;
}

/// Maps a lane-bar edge drag to its document edit: an element trim writes
/// its `show` bounds, a music-bed trim writes its source `trim`. Returns
/// null for a no-op.
VideoLaneEdit? videoBarResized(
  VideoLaneModel model,
  String barId,
  double newStart,
  double newEnd, {
  String? mergeGroup,
}) {
  if (model.isLocked(barId)) {
    return const VideoLaneEdit.refused('Unlock the lane before editing it.');
  }
  if (model.hasClipTransition(barId)) {
    return transitionClipWindowEdited(
      model,
      barId,
      newStart.round(),
      newEnd.round(),
      mergeGroup: mergeGroup,
    );
  }
  final overlay = model.overlayBars[barId];
  if (overlay != null) {
    final start = newStart.round().clamp(0, model.totalFrames - 1);
    final end = newEnd.round().clamp(start + 1, model.totalFrames);
    return _globalWindow(overlay, start, end, mergeGroup);
  }
  final element = model.elementBars[barId];
  if (element != null && element.members.isNotEmpty) {
    return _sharedWindow(
      element,
      newStart.round() - element.window.start,
      newEnd.round() - element.window.end,
      mergeGroup,
    );
  }
  if (element != null) return _elementResized(element, newStart, newEnd, mergeGroup);
  final audio = model.audioBars[barId];
  if (audio != null) return _audioResized(audio, newStart, newEnd, mergeGroup);
  return null;
}
