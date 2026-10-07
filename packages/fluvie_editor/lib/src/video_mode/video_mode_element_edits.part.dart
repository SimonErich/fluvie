part of 'video_mode_edits.dart';

VideoLaneEdit? _elementMoved(
  VideoLaneModel model,
  VideoElementLaneBinding binding,
  double newStart,
  String? mergeGroup,
) {
  final target = model.timebase.sceneAt(newStart.round());
  if (target != binding.scene) {
    return _elementMovedAcross(model, binding, target, newStart.round(), mergeGroup);
  }
  final localFrom = binding.window.start - binding.sceneSpan.start;
  final localTo = binding.window.end - binding.sceneSpan.start;
  final delta = newStart.round() - binding.window.start;
  final clamped = delta.clamp(-localFrom, binding.sceneSpan.durationFrames - localTo);
  if (clamped == 0) {
    return delta == 0 ? null : VideoLaneEdit.refused(_clampNote(model, binding, delta));
  }
  final command = SetShowWindowCommand(
    id: binding.elementId,
    fromFrames: localFrom + clamped,
    toFrames: localTo + clamped,
    mergeGroup: mergeGroup,
  );
  if (clamped == delta) return VideoLaneEdit.command(command);
  return VideoLaneEdit.clamped(command, _clampNote(model, binding, delta));
}

/// Why an in-scene move clamped: the video's edges are hard walls, and a
/// window whose end hits a slide boundary clamps until the bar's start
/// crosses it (the start picks the scene).
String _clampNote(VideoLaneModel model, VideoElementLaneBinding binding, int delta) {
  if (binding.scene == 0 && delta < 0) return 'Clamped at the video start.';
  if (binding.scene == model.timebase.sceneSpans.length - 1 && delta > 0) {
    return 'Clamped at the video end.';
  }
  return 'Clamped at the slide edge; drag the bar start into the next slide to move it.';
}

/// The bar's new start landed in [target]: the element moves there, its
/// window rewritten so the bar keeps its absolute position (pulled inside
/// the target's span when it would not fit). A group child never moves
/// alone, and a stepped element leaves its steps with an honest note.
VideoLaneEdit _elementMovedAcross(
  VideoLaneModel model,
  VideoElementLaneBinding binding,
  int target,
  int newStart,
  String? mergeGroup,
) {
  if (binding.isGrouped) {
    return const VideoLaneEdit.refused('A grouped element moves with its group.');
  }
  final span = model.timebase.sceneSpans[target];
  final length = binding.window.durationFrames;
  final fit = span.durationFrames - length;
  final from = (newStart - span.start).clamp(0, fit < 0 ? 0 : fit);
  final to = (from + length).clamp(from + 1, span.durationFrames);
  final command = MoveElementToSceneCommand(
    id: binding.elementId,
    toScene: target,
    fromFrames: from,
    toFrames: to,
    mergeGroup: mergeGroup,
  );
  final notes = [
    if (binding.inSteps) "Left slide ${binding.scene + 1}'s build steps.",
    if (from != newStart - span.start || to - from != length) 'Clamped inside slide ${target + 1}.',
  ];
  if (notes.isEmpty) return VideoLaneEdit.command(command);
  return VideoLaneEdit.clamped(command, notes.join(' '));
}

VideoLaneEdit? _elementResized(
  VideoElementLaneBinding binding,
  double newStart,
  double newEnd,
  String? mergeGroup,
) {
  final sceneLength = binding.sceneSpan.durationFrames;
  final from = (newStart.round() - binding.sceneSpan.start).clamp(0, sceneLength - 1);
  final to = (newEnd.round() - binding.sceneSpan.start).clamp(from + 1, sceneLength);
  if (from == binding.window.start - binding.sceneSpan.start &&
      to == binding.window.end - binding.sceneSpan.start) {
    return null;
  }
  return VideoLaneEdit.command(
    SetShowWindowCommand(
      id: binding.elementId,
      fromFrames: from,
      toFrames: to,
      mergeGroup: mergeGroup,
    ),
  );
}
