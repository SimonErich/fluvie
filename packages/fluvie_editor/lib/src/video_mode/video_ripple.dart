import 'package:fluvie/fluvie.dart' show FrameSpan;
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/video_mode/video_audio_structure.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_model.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_neighbours.dart';
import 'package:fluvie_editor/src/video_mode/video_mode_edits.dart';

part 'video_ripple_trim.part.dart';
part 'video_ripple_audio.part.dart';

/// Deletes the bars [barIds] name and pulls what followed them back into the
/// gap, one undo step.
///
/// A ripple never changes a slide's length. Windows are scene-relative, so
/// closing a gap can only move what is on the same slide; the slide keeps the
/// frames it had, and where nothing follows, the gap stays and says so.
///
/// A clip that *overlaps* a deleted span stays where it is. Pulling it back
/// would move it somewhere the author never put it, so the ripple closes what
/// it can and names what it left.
VideoLaneEdit? videoRippleDeleted(
  VideoLaneModel model,
  Set<String> barIds, {
  required EditorDocument document,
  String? mergeGroup,
}) {
  if (barIds.isEmpty) return null;
  if (barIds.any(model.isLocked)) {
    return const VideoLaneEdit.refused('Unlock the lane before deleting its material.');
  }
  final removed = [
    for (final barId in barIds)
      if (model.elementBars[barId] case final binding?)
        for (final member in binding.members.isEmpty ? [binding] : binding.members)
          (barId: barId, binding: member),
  ];
  final removedAudio = [for (final id in barIds) ?model.audioBars[id]];
  if (removed.isEmpty && removedAudio.isEmpty) return null;
  for (final binding in removedAudio) {
    final reason = audioStructureRefusal(
      binding,
      document.audioTracksJson(scene: binding.scene)[binding.index],
    );
    if (reason != null) return VideoLaneEdit.refused(reason);
  }
  // Patches precede removals: an audio index remains its original address until
  // all moves are written, then descending removals cannot address a neighbour.
  final commands = <EditorCommand>[];
  var shifted = 0;
  var overlapped = 0;
  for (final scene in <int?>{
    for (final bar in removed) bar.binding.scene,
    for (final bar in removedAudio) bar.scene,
  }) {
    final gaps = _mergedGaps([
      for (final bar in removed)
        if (bar.binding.scene == scene) bar.binding.window,
      for (final bar in removedAudio)
        if (bar.scene == scene) bar.span,
    ]);
    final gone = {for (final bar in removed) bar.barId};
    for (final bar in scene == null ? <VideoLaneBar>[] : _membersInScene(model, scene)) {
      if (gone.contains(bar.barId)) continue;
      final start = bar.binding.window.start;
      if (gaps.any((gap) => start > gap.start && start < gap.end)) {
        overlapped++;
        continue;
      }
      final pull = gaps
          .where((gap) => gap.end <= start)
          .fold(0, (total, gap) => total + (gap.end - gap.start));
      if (pull == 0) continue;
      if (model.isLocked(bar.barId)) {
        return const VideoLaneEdit.refused('Unlock following material before rippling this gap.');
      }
      shifted++;
      final sceneStart = bar.binding.sceneSpan.start;
      commands.add(
        SetShowWindowCommand(
          id: bar.binding.elementId,
          fromFrames: start - sceneStart - pull,
          toFrames: bar.binding.window.end - sceneStart - pull,
        ),
      );
    }
    for (final entry in model.audioBars.entries) {
      final binding = entry.value;
      if (binding.scene != scene || barIds.contains(entry.key)) continue;
      final start = binding.span.start;
      if (gaps.any((gap) => start > gap.start && start < gap.end)) {
        overlapped++;
        continue;
      }
      final pull = gaps
          .where((gap) => gap.end <= start)
          .fold(0, (total, gap) => total + gap.end - gap.start);
      if (pull == 0) continue;
      if (model.isLocked(entry.key)) {
        return const VideoLaneEdit.refused('Unlock following audio before rippling this gap.');
      }
      final reason = audioStructureRefusal(
        binding,
        document.audioTracksJson(scene: scene)[binding.index],
      );
      if (reason != null) return VideoLaneEdit.refused(reason);
      commands.add(audioShiftCommand(model, binding, document, -pull));
      shifted++;
    }
  }
  commands.addAll([for (final bar in removed) RemoveElementCommand(id: bar.binding.elementId)]);
  removedAudio.sort((a, b) => b.index.compareTo(a.index));
  commands.addAll([
    for (final bar in removedAudio) RemoveAudioTrackCommand(index: bar.index, scene: bar.scene),
  ]);
  final note = overlapped > 0
      ? 'Left $overlapped clip${overlapped == 1 ? '' : 's'} that overlap the gap where '
            'they were.'
      : shifted == 0
      ? 'Nothing after it to pull back, and a ripple never changes a slide length.'
      : null;
  final command = SequenceCommand(commands, label: 'Ripple delete', mergeGroup: mergeGroup);
  return note == null ? VideoLaneEdit.command(command) : VideoLaneEdit.clamped(command, note);
}

List<VideoLaneBar> _membersInScene(VideoLaneModel model, int scene) => [
  for (final entry in model.elementBars.entries)
    for (final member in entry.value.members.isEmpty ? [entry.value] : entry.value.members)
      if (member.scene == scene) (barId: entry.key, binding: member),
];

/// The removed windows merged into non-overlapping gaps, so a clip after two
/// touching deletions is pulled back once by their total, not twice.
List<({int start, int end})> _mergedGaps(List<FrameSpan> windows) {
  final spans = [
    for (final window in windows) (start: window.start, end: window.end),
  ]..sort((a, b) => a.start.compareTo(b.start));
  final merged = <({int start, int end})>[];
  for (final span in spans) {
    if (merged.isNotEmpty && span.start <= merged.last.end) {
      final last = merged.removeLast();
      merged.add((start: last.start, end: span.end > last.end ? span.end : last.end));
    } else {
      merged.add(span);
    }
  }
  return merged;
}
