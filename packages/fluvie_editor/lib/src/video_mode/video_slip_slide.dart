import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/video_mode/clip_slip_source.dart';
import 'package:fluvie_editor/src/video_mode/clip_trim_seconds.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_bindings.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_model.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_neighbours.dart';
import 'package:fluvie_editor/src/video_mode/video_mode_edits.dart';

part 'video_slide.part.dart';

/// Moves the cut between [barId] and the clip that starts where it ends, by
/// [delta] frames, holding the pair's outer edges.
///
/// A roll is the only edit that changes two clips and changes nothing else:
/// one gets longer by exactly what the other gives up, so nothing downstream
/// moves at all.
VideoLaneEdit? videoRolled(
  VideoLaneModel model,
  String barId,
  int delta, {
  required EditorDocument document,
  String? mergeGroup,
}) {
  if (delta == 0) return null;
  if (model.isLocked(barId)) {
    return const VideoLaneEdit.refused('Unlock the lane before editing it.');
  }
  final binding = model.elementBars[barId];
  if (binding == null) return null;
  if (binding.members.isNotEmpty) {
    return const VideoLaneEdit.refused('Use the shared bar handles to edit its timing.');
  }
  final next = barsStartingAt(model, binding.scene, binding.window.end, except: barId);
  if (next.length != 1) {
    return VideoLaneEdit.refused(
      next.isEmpty
          ? 'No clip starts where this one ends, so there is no cut to roll.'
          : 'More than one clip starts where this one ends, so there is no single '
                'cut to roll.',
    );
  }
  if (model.isLocked(next.single.barId)) {
    return const VideoLaneEdit.refused('Unlock both lanes before rolling a cut.');
  }
  final other = next.single.binding;
  // Neither side may be swallowed whole: a clip with no frames left is a
  // delete the author did not ask for.
  final cut = (binding.window.end + delta).clamp(binding.window.start + 1, other.window.end - 1);
  if (cut == binding.window.end) {
    return const VideoLaneEdit.refused('The cut is already as far as it goes.');
  }
  final start = binding.sceneSpan.start;
  final command = SequenceCommand(
    [
      SetShowWindowCommand(
        id: binding.elementId,
        fromFrames: binding.window.start - start,
        toFrames: cut - start,
      ),
      SetShowWindowCommand(
        id: other.elementId,
        fromFrames: cut - start,
        toFrames: other.window.end - start,
      ),
    ],
    label: 'Roll',
    mergeGroup: mergeGroup,
  );
  return cut == binding.window.end + delta
      ? VideoLaneEdit.command(command)
      : VideoLaneEdit.clamped(command, 'Rolled as far as the pair allows.');
}

/// Moves the source under [barId] by [delta] composition frames, holding the
/// window exactly where it is.
///
/// A slip changes which part of the footage plays and nothing else: the clip
/// occupies the same frames, so nothing around it moves either.
///
/// [baseline] is the element as it was when a drag began. A drag hands the
/// whole travel each update and measures it from there, rather than adding one
/// increment to what it wrote last time: seconds are not integers, and a long
/// drag adding hundreds of them would visibly drift.
/// [baselineMembers] captures each shared member at the same pointer-down;
/// every update translates those source ranges atomically, preserving the
/// independent geometry, timing, audio and speed curve of every member.
VideoLaneEdit? videoSlipped(
  VideoLaneModel model,
  String barId,
  int delta, {
  required EditorDocument document,
  Map<String, Object?>? baseline,
  Map<String, Map<String, Object?>>? baselineMembers,
  String? mergeGroup,
}) {
  if (delta == 0 && baseline == null && baselineMembers == null) return null;
  if (model.isLocked(barId)) {
    return const VideoLaneEdit.refused('Unlock the lane before editing it.');
  }
  final binding = model.elementBars[barId];
  if (binding == null) return null;
  final members = binding.members.isEmpty ? [binding] : binding.members;
  final originals = <String, Map<String, Object?>>{};
  final sources = <String, ClipSlipSource>{};
  var travel = delta.toDouble();
  for (final member in members) {
    final id = member.elementId;
    final element =
        baselineMembers?[id] ??
        (id == binding.elementId ? baseline : null) ??
        document.elementJson(id);
    if (element == null) return null;
    if (element['type'] != 'Clip') {
      return const VideoLaneEdit.refused('Only a clip has source to slip.');
    }
    final lane = document.spec.lanes.where((lane) => lane.id == element['lane']).firstOrNull;
    if (lane?.locked ?? false) {
      return const VideoLaneEdit.refused('Unlock every shared member’s lane before slipping.');
    }
    final trim = readClipTrimSeconds(element);
    if (trim == null) return const VideoLaneEdit.refused(clipTrimUnitNote);
    final source = ClipSlipSource(element, trim, member.window.durationFrames, model.fps);
    originals[id] = element;
    sources[id] = source;
    if (travel < source.earliest) travel = source.earliest;
  }
  if (travel == 0 && delta != 0) {
    return const VideoLaneEdit.refused('Already at the start of the source.');
  }
  final replacements = <String, Map<String, Object?>>{};
  for (final entry in sources.entries) {
    final source = entry.value;
    final shift = source.offset(travel);
    final from = (source.from + shift).clamp(0.0, double.infinity);
    replacements[entry.key] = {
      ...originals[entry.key]!,
      if (delta != 0) 'trim': trimSecondsJson(from, source.to + shift),
    };
  }
  final command = binding.members.isEmpty
      ? ReplaceElementCommand(
          id: binding.elementId,
          element: replacements[binding.elementId]!,
          mergeGroup: mergeGroup,
        )
      : ReplaceSharedMembersCommand(
          members: replacements,
          label: 'Slip shared clips',
          mergeGroup: mergeGroup,
        );
  return travel == delta
      ? VideoLaneEdit.command(command)
      : VideoLaneEdit.clamped(command, 'Slipped as far as the source start allows.');
}
