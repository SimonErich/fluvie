import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_model.dart';
import 'package:fluvie_editor/src/video_mode/video_mode_edits.dart';

/// Moves material onto a declared or implicit timeline lane, without altering
/// its time or source. Locked rows refuse both incoming and outgoing material.
VideoLaneEdit? videoBarRelaned(
  VideoLaneModel model,
  String barId,
  String targetRowId, {
  required EditorDocument document,
  String? mergeGroup,
}) {
  if (targetRowId == 'scenes' || targetRowId.startsWith('fx')) return null;
  final target = model.tracks.where((row) => row.id == targetRowId).firstOrNull;
  if (target == null &&
      !targetRowId.startsWith('el-track:') &&
      !targetRowId.startsWith('overlay-track:') &&
      !targetRowId.startsWith('audio-track:')) {
    return null;
  }
  if (model.isLocked(barId) || (target?.locked ?? false)) {
    return const VideoLaneEdit.refused('Unlock the lane before moving material onto or off it.');
  }
  final lane = laneIdOfRow(targetRowId);
  final audio = model.audioBars[barId];
  if (audio != null) {
    final track = document.audioTracksJson(scene: audio.scene)[audio.index];
    if (track['lane'] == lane) return null;
    return VideoLaneEdit.command(
      SetAudioTrackCommand(
        index: audio.index,
        scene: audio.scene,
        patch: {'lane': lane},
        mergeGroup: mergeGroup,
      ),
    );
  }
  final id = model.elementBars[barId]?.elementId ?? model.overlayBars[barId]?.elementId;
  if (id == null) return null;
  if (document.elementJson(id)?['lane'] == lane) return null;
  final command = SetElementLaneCommand(id: id, lane: lane, mergeGroup: mergeGroup);
  try {
    command.apply(document);
    return VideoLaneEdit.command(command);
  } on Object catch (error) {
    return VideoLaneEdit.refused('The lane change would invalidate this clip: $error');
  }
}
