part of 'video_ripple.dart';

VideoLaneEdit? _audioRippleTrimmed(
  VideoLaneModel model,
  String barId,
  int newStart,
  int newEnd, {
  required EditorDocument document,
  String? mergeGroup,
}) {
  final binding = model.audioBars[barId]!;
  if (model.isLocked(barId)) {
    return const VideoLaneEdit.refused('Unlock the lane before trimming audio.');
  }
  final raw = document.audioTracksJson(scene: binding.scene)[binding.index];
  final reason = audioStructureRefusal(binding, raw);
  if (reason != null) return VideoLaneEdit.refused(reason);
  if (newStart == binding.span.start && newEnd == binding.span.end) return null;
  if (newStart < binding.span.start || newEnd > binding.span.end) {
    return const VideoLaneEdit.refused(
      'Extend the source trim first; a ripple trim keeps the known source window.',
    );
  }
  if (newEnd <= newStart) {
    return const VideoLaneEdit.refused('An audio trim must keep at least one frame.');
  }
  final delta = newEnd - binding.span.end;
  final commands = <EditorCommand>[
    SetAudioTrackCommand(
      index: binding.index,
      scene: binding.scene,
      patch: audioWindowPatch(model, binding, document, newStart, newEnd),
    ),
  ];
  if (delta != 0) {
    final scene = binding.scene;
    if (scene != null) {
      for (final bar in _membersInScene(model, scene)) {
        if (bar.binding.window.start < binding.span.end) continue;
        if (model.isLocked(bar.barId)) {
          return const VideoLaneEdit.refused(
            'Unlock following material before ripple trimming audio.',
          );
        }
        final ownerStart = bar.binding.sceneSpan.start;
        commands.add(
          SetShowWindowCommand(
            id: bar.binding.elementId,
            fromFrames: bar.binding.window.start - ownerStart + delta,
            toFrames: bar.binding.window.end - ownerStart + delta,
          ),
        );
      }
    }
    final audio = _followingAudioShift(
      model,
      document,
      scene,
      binding.span.end,
      delta,
      except: barId,
    );
    if (audio.note != null) return VideoLaneEdit.refused(audio.note!);
    commands.addAll(audio.commands);
  }
  return VideoLaneEdit.command(
    SequenceCommand(commands, label: 'Ripple trim audio', mergeGroup: mergeGroup),
  );
}

({List<EditorCommand> commands, String? note}) _followingAudioShift(
  VideoLaneModel model,
  EditorDocument document,
  int? scene,
  int boundary,
  int delta, {
  String? except,
}) {
  final commands = <EditorCommand>[];
  for (final entry in model.audioBars.entries) {
    final binding = entry.value;
    if (entry.key == except || binding.scene != scene || binding.span.start < boundary) continue;
    if (model.isLocked(entry.key)) {
      return (commands: const [], note: 'Unlock following audio before ripple trimming.');
    }
    final reason = audioStructureRefusal(
      binding,
      document.audioTracksJson(scene: scene)[binding.index],
    );
    if (reason != null) return (commands: const [], note: reason);
    final owner = audioOwnerSpan(model, binding);
    if (binding.span.start + delta < owner.start || binding.span.end + delta > owner.end) {
      return (
        commands: const [],
        note: 'The ripple would push following audio outside its owner window.',
      );
    }
    commands.add(audioShiftCommand(model, binding, document, delta));
  }
  return (commands: commands, note: null);
}
