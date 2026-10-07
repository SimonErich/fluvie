part of 'video_ripple.dart';

/// Trims the bar [barId] to `newStart..newEnd` and moves what followed it by
/// the same amount, one undo step.
///
/// Only the out edge ripples. A clip's end is where the next one waits; its
/// start is not, so trimming the head leaves everything after exactly where it
/// was and a ripple there is simply a trim.
VideoLaneEdit? videoRippleTrimmed(
  VideoLaneModel model,
  String barId,
  int newStart,
  int newEnd, {
  required EditorDocument document,
  String? mergeGroup,
}) {
  if (model.audioBars.containsKey(barId)) {
    return _audioRippleTrimmed(
      model,
      barId,
      newStart,
      newEnd,
      document: document,
      mergeGroup: mergeGroup,
    );
  }
  final binding = model.elementBars[barId];
  if (binding == null) return null;
  if (binding.members.isNotEmpty) {
    final trimmed = videoBarResized(
      model,
      barId,
      newStart.toDouble(),
      newEnd.toDouble(),
      mergeGroup: mergeGroup,
    );
    if (trimmed?.command == null) return trimmed;
    final commands = <EditorCommand>[trimmed!.command!];
    final updated = VideoLaneModel.build(document: trimmed.command!.apply(document));
    for (final member in binding.members) {
      final updatedMember = updated.elementBars.values
          .expand((bar) => bar.members.isEmpty ? [bar] : bar.members)
          .firstWhere((bar) => bar.elementId == member.elementId);
      final delta = updatedMember.window.end - member.window.end;
      if (delta == 0) continue;
      for (final bar in _membersInScene(model, member.scene)) {
        if (bar.barId == barId || bar.binding.window.start < member.window.end) {
          continue;
        }
        if (model.isLocked(bar.barId)) {
          return const VideoLaneEdit.refused('Unlock following material before ripple trimming.');
        }
        final start = bar.binding.window.start - member.sceneSpan.start + delta;
        final end = bar.binding.window.end - member.sceneSpan.start + delta;
        if (start < 0 || end > member.sceneSpan.durationFrames) {
          return const VideoLaneEdit.refused(
            'The shared ripple would push following material outside its scene.',
          );
        }
        commands.add(
          SetShowWindowCommand(id: bar.binding.elementId, fromFrames: start, toFrames: end),
        );
      }
    }
    for (final member in binding.members) {
      final updatedMember = updated.elementBars.values
          .expand((bar) => bar.members.isEmpty ? [bar] : bar.members)
          .firstWhere((bar) => bar.elementId == member.elementId);
      final delta = updatedMember.window.end - member.window.end;
      if (delta == 0) continue;
      final audio = _followingAudioShift(model, document, member.scene, member.window.end, delta);
      if (audio.note != null) return VideoLaneEdit.refused(audio.note!);
      commands.addAll(audio.commands);
    }
    return VideoLaneEdit.command(
      SequenceCommand(commands, label: 'Ripple shared chain', mergeGroup: mergeGroup),
    );
  }
  final trimmed = videoBarResized(
    model,
    barId,
    newStart.toDouble(),
    newEnd.toDouble(),
    mergeGroup: mergeGroup,
  );
  final trim = trimmed?.command;
  if (trim == null) return trimmed;
  final sceneLength = binding.sceneSpan.durationFrames;
  final sceneStart = binding.sceneSpan.start;
  final end = newEnd.clamp(binding.window.start + 1, binding.sceneSpan.end);
  final delta = end - binding.window.end;
  if (delta == 0) return trimmed;
  final commands = <EditorCommand>[trim];
  var clamped = false;
  for (final bar in sceneElementBars(model, binding.scene)) {
    if (bar.barId == barId ||
        bar.binding.members.isNotEmpty ||
        bar.binding.window.start < binding.window.end) {
      continue;
    }
    if (model.isLocked(bar.barId)) {
      return const VideoLaneEdit.refused('Unlock following material before ripple trimming.');
    }
    final from = bar.binding.window.start - sceneStart + delta;
    final to = bar.binding.window.end - sceneStart + delta;
    final fitFrom = from.clamp(0, sceneLength - 1);
    final fitTo = to.clamp(fitFrom + 1, sceneLength);
    if (fitFrom != from || fitTo != to) clamped = true;
    commands.add(
      SetShowWindowCommand(id: bar.binding.elementId, fromFrames: fitFrom, toFrames: fitTo),
    );
  }
  final audio = _followingAudioShift(model, document, binding.scene, binding.window.end, delta);
  if (audio.note != null) return VideoLaneEdit.refused(audio.note!);
  commands.addAll(audio.commands);
  final command = SequenceCommand(commands, label: 'Ripple trim', mergeGroup: mergeGroup);
  return clamped
      ? VideoLaneEdit.clamped(
          command,
          'Clamped at the slide edge; a ripple never lengthens a slide.',
        )
      : VideoLaneEdit.command(command);
}
