part of 'video_mode_edits.dart';

VideoLaneEdit? _globalWindow(VideoOverlayLaneBinding overlay, int start, int end, String? group) {
  if (start == overlay.window.start && end == overlay.window.end) return null;
  return VideoLaneEdit.command(
    SetShowWindowCommand(
      id: overlay.elementId,
      fromFrames: start,
      toFrames: end,
      mergeGroup: group,
    ),
  );
}

/// A chain keeps its scene memberships. Move and trim apply the same edge
/// deltas to every member, preserving each member's geometry and local clock.
VideoLaneEdit? _sharedWindow(
  VideoElementLaneBinding chain,
  int headDelta,
  int tailDelta,
  String? group, {
  bool moving = false,
}) {
  if (headDelta == 0 && tailDelta == 0) return null;
  var head = headDelta;
  var tail = tailDelta;
  if (moving) {
    for (final member in chain.members) {
      head = head.clamp(
        member.sceneSpan.start - member.window.start,
        member.sceneSpan.end - member.window.end,
      );
    }
    tail = head;
  }
  final commands = <EditorCommand>[];
  var clamped = head != headDelta || tail != tailDelta;
  for (final member in chain.members) {
    final start = member.window.start - member.sceneSpan.start;
    final end = member.window.end - member.sceneSpan.start;
    final from = (start + head).clamp(0, member.sceneSpan.durationFrames - 1);
    final to = (end + tail).clamp(from + 1, member.sceneSpan.durationFrames);
    if (from != start + head || to != end + tail) clamped = true;
    if (from != start || to != end) {
      commands.add(SetShowWindowCommand(id: member.elementId, fromFrames: from, toFrames: to));
    }
  }
  const note = 'Shared timing stays inside each member scene; clamped at a scene edge.';
  if (commands.isEmpty) return clamped ? const VideoLaneEdit.refused(note) : null;
  final command = SequenceCommand(commands, label: 'Edit shared timing', mergeGroup: group);
  return clamped ? VideoLaneEdit.clamped(command, note) : VideoLaneEdit.command(command);
}
