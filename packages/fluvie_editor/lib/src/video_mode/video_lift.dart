import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/video_mode/video_audio_structure.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_model.dart';
import 'package:fluvie_editor/src/video_mode/video_mode_edits.dart';
import 'package:fluvie_editor/src/video_mode/video_razor.dart';
import 'package:fluvie_editor/src/video_mode/video_ripple.dart';

/// Removes selected material without moving anything else. A shared chain is
/// removed atomically, as the single logical bar the user selected.
VideoLaneEdit? videoLifted(
  VideoLaneModel model,
  Set<String> bars, {
  required EditorDocument document,
}) {
  if (bars.any(model.isLocked)) {
    return const VideoLaneEdit.refused('Unlock the lane before lifting its material.');
  }
  final commands = <EditorCommand>[];
  for (final bar in bars) {
    final element = model.elementBars[bar];
    final overlay = model.overlayBars[bar];
    if (element != null) {
      for (final id in document.sharedChainIds(element.elementId)) {
        commands.add(RemoveElementCommand(id: id));
      }
    } else if (overlay != null) {
      commands.add(RemoveElementCommand(id: overlay.elementId));
    }
  }
  // Delete backwards within each audio list so positional identities remain valid.
  final audio = [
    for (final id in bars) ?model.audioBars[id],
  ]..sort((a, b) => b.index.compareTo(a.index));
  commands.addAll([
    for (final binding in audio)
      RemoveAudioTrackCommand(index: binding.index, scene: binding.scene),
  ]);
  if (commands.isEmpty) return null;
  return VideoLaneEdit.command(SequenceCommand(commands, label: 'Lift'));
}

/// Removes the marked range from the chosen clips. Cuts retain source trim;
/// extract additionally closes each scene's gap, while lift leaves the gap.
VideoLaneEdit? videoRangeRemoved(
  VideoLaneModel model,
  int from,
  int to, {
  required EditorDocument document,
  Set<String>? bars,
  bool ripple = false,
}) {
  if (to <= from) return null;
  final candidates =
      bars ?? {...model.elementBars.keys, ...model.overlayBars.keys, ...model.audioBars.keys};
  final intersecting = candidates.where((id) {
    final binding = model.elementBars[id];
    final window = binding?.window ?? model.overlayBars[id]?.window ?? model.audioBars[id]?.span;
    return window != null && window.start < to && window.end > from;
  }).toList();
  if (intersecting.any(model.isLocked)) {
    return const VideoLaneEdit.refused('Unlock the lane before editing its range.');
  }
  if (ripple && intersecting.any(model.overlayBars.containsKey)) {
    return const VideoLaneEdit.refused(
      'Global overlays do not ripple with scene-local clips. Lift their marked range instead.',
    );
  }
  var current = document;
  final commands = <EditorCommand>[];
  final cutBars = <String>{};
  for (final originalId in intersecting) {
    var barId = originalId;
    var latest = VideoLaneModel.build(document: current);
    var window =
        latest.elementBars[barId]?.window ??
        latest.overlayBars[barId]?.window ??
        latest.audioBars[barId]?.span;
    if (window == null) continue;
    for (final frame in [from, to]) {
      if (frame <= window!.start || frame >= window.end) continue;
      final audio = latest.audioBars[barId];
      final audioTail = audio == null
          ? null
          : audioBarId(audio.scene, current.audioTracksJson(scene: audio.scene).length);
      final tail = current.nextId();
      final edit = videoBarRazored(latest, barId, frame, document: current, tailId: tail);
      if (edit?.command == null) return edit;
      commands.add(edit!.command!);
      current = edit.command!.apply(current);
      if (frame == from) {
        final command = edit.command;
        final actualTail = command is SplitSharedChainCommand ? command.tailPrimaryId : tail;
        barId = audioTail ?? '${originalId.startsWith('overlay:') ? 'overlay' : 'el'}:$actualTail';
      }
      latest = VideoLaneModel.build(document: current);
      window =
          latest.elementBars[barId]?.window ??
          latest.overlayBars[barId]?.window ??
          latest.audioBars[barId]?.span;
    }
    cutBars.add(barId);
  }
  final latest = VideoLaneModel.build(document: current);
  final removal = ripple
      ? videoRippleDeleted(latest, cutBars, document: current)
      : videoLifted(latest, cutBars, document: current);
  if (removal?.command == null) return removal;
  commands.add(removal!.command!);
  final sequence = SequenceCommand(commands, label: ripple ? 'Extract range' : 'Lift range');
  return removal.note == null
      ? VideoLaneEdit.command(sequence)
      : VideoLaneEdit.clamped(sequence, removal.note!);
}
