import 'package:fluvie/fluvie.dart'
    show KeyframedNumber, RelativeTime, decodeTime, introspectTimeline;
import 'package:fluvie/rendering.dart' show integrateClipSpeedRamp;
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/video_mode/clip_trim_seconds.dart';
import 'package:fluvie_editor/src/video_mode/video_element_owner.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_model.dart';
import 'package:fluvie_editor/src/video_mode/video_mode_edits.dart';
import 'package:fluvie_editor/src/video_mode/video_timebase.dart';

part 'clip_speed_ramp.part.dart';
part 'clip_speed_shared.part.dart';

/// Edits constant clip speed while preserving its selected source range.
/// Whole-frame duration rounding is reflected in the persisted speed so picture
/// and audio consume exactly the same range. A negative speed reverses picture.
VideoLaneEdit clipSpeedEdited(
  EditorDocument document,
  String id,
  double speed, {
  String? mergeGroup,
}) {
  if (!speed.isFinite || speed == 0) {
    return const VideoLaneEdit.refused('Speed must be finite and nonzero.');
  }
  final element = document.elementJson(id);
  if (element == null || element['type'] != 'Clip') {
    return const VideoLaneEdit.refused('Select a clip to change speed.');
  }
  final lane = document.spec.lanes.where((lane) => lane.id == element['lane']).firstOrNull;
  if (lane?.locked ?? false) {
    return const VideoLaneEdit.refused('Unlock the lane before changing speed.');
  }
  if (element['shared'] != null) {
    return _sharedSpeedEdited(
      document,
      id,
      (local, member) => clipSpeedEdited(local, member, speed),
      mergeGroup: mergeGroup,
    );
  }
  final trim = readClipTrimSeconds(element);
  if (trim == null) return const VideoLaneEdit.refused(clipTrimUnitNote);
  final timeline = introspectTimeline(document.spec.build());
  final span = videoElementOwner(document, timeline, id);
  final scope = OwnerFrameScope(document.spec.fps, span);
  final show = element['show'] as Map<String, Object?>?;
  final from = show?['from'] == null ? 0 : decodeTime(show!['from']).resolveFrames(scope);
  final oldTo = show?['to'] == null
      ? span.durationFrames
      : decodeTime(show!['to']).resolveFrames(scope);
  final sourceSeconds = trim.toOpen
      ? _consumed(element, document.spec.fps, oldTo - from)
      : trim.to - trim.from;
  final duration = (sourceSeconds * document.spec.fps / speed.abs()).round();
  if (duration < 1 || from + duration > span.durationFrames) {
    return const VideoLaneEdit.refused(
      'This speed does not fit inside the clip’s scene or group. Extend the scene first.',
    );
  }
  final actualSpeed = sourceSeconds * document.spec.fps / duration * speed.sign;
  final command = ReplaceElementCommand(
    id: id,
    element: {
      ...element,
      'speed': actualSpeed,
      'show': {'from': '${from}f', 'to': '${from + duration}f'},
      'trim': trimSecondsJson(trim.from, trim.from + sourceSeconds),
    },
    mergeGroup: mergeGroup,
  );
  try {
    command.apply(document);
  } on Object catch (error) {
    return VideoLaneEdit.refused('Speed refused: $error');
  }
  return VideoLaneEdit.command(command);
}

/// Links the right-edge duration to playback speed, preserving source in/out.
VideoLaneEdit clipRateStretched(
  EditorDocument document,
  VideoLaneModel model,
  String barId,
  double end, {
  String? mergeGroup,
}) {
  final binding = model.elementBars[barId];
  if (binding == null) {
    return const VideoLaneEdit.refused('Rate stretch applies to a clip’s right edge.');
  }
  final element = document.elementJson(binding.elementId);
  if (element == null || element['type'] != 'Clip') {
    return const VideoLaneEdit.refused('Rate stretch applies to clips.');
  }
  if (binding.members.isNotEmpty) {
    final terminal = binding.members.reduce((a, b) => a.window.end > b.window.end ? a : b);
    final terminalDuration = end.round() - terminal.window.start;
    if (terminalDuration < 1) {
      return const VideoLaneEdit.refused(
        'Rate stretch must leave the last shared member at least one frame.',
      );
    }
    final scale = terminalDuration / terminal.window.durationFrames;
    final byId = {for (final member in binding.members) member.elementId: member};
    final edit = _sharedSpeedEdited(
      document,
      binding.elementId,
      (local, member) {
        final window = byId[member]!.window;
        return clipRateStretched(
          local,
          VideoLaneModel.build(document: local),
          'el:$member',
          (window.start + (window.durationFrames * scale).round()).toDouble(),
        );
      },
      mergeGroup: mergeGroup,
    );
    if (edit.command case final command?) {
      final actual = VideoLaneModel.build(
        document: command.apply(document),
      ).elementBars[barId]!.window.end;
      if (actual != end.round()) {
        return const VideoLaneEdit.refused(
          'Another shared member extends past this edge. Shorten that member first.',
        );
      }
    }
    return edit;
  }
  final duration = end.round() - binding.window.start;
  if (duration < 1) return const VideoLaneEdit.refused('A clip needs at least one frame.');
  final ramp = KeyframedNumber.maybeFromJson(element['speed']);
  if (ramp != null) {
    return clipSpeedRampEdited(
      document,
      binding.elementId,
      ramp,
      durationFrames: duration,
      mergeGroup: mergeGroup,
    );
  }
  return clipSpeedEdited(
    document,
    binding.elementId,
    clipSpeedOf(element) * binding.window.durationFrames / duration,
    mergeGroup: mergeGroup,
  );
}
