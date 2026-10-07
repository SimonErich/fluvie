part of 'video_slip_slide.dart';

/// Moves [barId]'s window by [delta] frames and lets the clips it touches
/// absorb the move, holding its content exactly where it is.
///
/// The mirror of a slip: a slide changes when the clip plays without changing
/// what it plays, and the neighbours give up (or take back) the frames it
/// crosses, so nothing beyond the pair moves.
VideoLaneEdit? videoSlid(
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
  final before = barsEndingAt(model, binding.scene, binding.window.start, except: barId);
  final after = barsStartingAt(model, binding.scene, binding.window.end, except: barId);
  if ([...before, ...after].any((bar) => model.isLocked(bar.barId))) {
    return const VideoLaneEdit.refused('Unlock neighbouring lanes before sliding.');
  }
  if (before.length > 1 || after.length > 1) {
    return const VideoLaneEdit.refused(
      'More than one clip meets this one, so there is no single pair to slide between.',
    );
  }
  if (before.isEmpty && after.isEmpty) {
    return const VideoLaneEdit.refused(
      'This clip has no neighbour to slide against. Drag it to move it instead.',
    );
  }
  final start = binding.sceneSpan.start;
  final length = binding.sceneSpan.durationFrames;
  var moved = delta;
  // Neither neighbour may be swallowed whole, and the clip stays on its slide.
  if (before.isNotEmpty) {
    final previous = before.single.binding.window;
    moved = moved.clamp(previous.start + 1 - previous.end, length);
  }
  if (after.isNotEmpty) {
    final next = after.single.binding.window;
    moved = moved.clamp(-length, next.end - 1 - next.start);
  }
  moved = moved.clamp(
    start - binding.window.start,
    start + length - binding.window.end,
  );
  if (moved == 0) return const VideoLaneEdit.refused('There is no room to slide it further.');
  final command = SequenceCommand(
    [
      if (before.isNotEmpty) _window(before.single.binding, start, to: moved),
      SetShowWindowCommand(
        id: binding.elementId,
        fromFrames: binding.window.start - start + moved,
        toFrames: binding.window.end - start + moved,
      ),
      if (after.isNotEmpty) _window(after.single.binding, start, from: moved),
    ],
    label: 'Slide',
    mergeGroup: mergeGroup,
  );
  return moved == delta
      ? VideoLaneEdit.command(command)
      : VideoLaneEdit.clamped(command, 'Slid as far as the neighbours allow.');
}

/// A neighbour's window with one edge moved by [from] or [to] frames.
SetShowWindowCommand _window(
  VideoElementLaneBinding binding,
  int sceneStart, {
  int from = 0,
  int to = 0,
}) => SetShowWindowCommand(
  id: binding.elementId,
  fromFrames: binding.window.start - sceneStart + from,
  toFrames: binding.window.end - sceneStart + to,
);
