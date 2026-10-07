part of 'video_mode_edits.dart';

VideoLaneEdit? _audioMoved(
  VideoLaneModel model,
  VideoAudioLaneBinding binding,
  double newStart,
  String? mergeGroup,
) {
  if (newStart.round() == binding.span.start) return null;
  if (binding.at == VideoAudioAt.trigger) {
    return const VideoLaneEdit.refused(
      'This audio track fires on a trigger; a drag would replace it.',
    );
  }
  final owner = _ownerOf(model, binding);
  final offset = (newStart.round() - owner.start).clamp(0, owner.length);
  if (offset == binding.span.start - owner.start) return null;
  return VideoLaneEdit.command(
    SetAudioTrackCommand(
      scene: binding.scene,
      index: binding.index,
      patch: {
        'at': {'kind': 'at', 'time': '${offset}f'},
      },
      mergeGroup: mergeGroup,
    ),
  );
}

VideoLaneEdit? _audioResized(
  VideoAudioLaneBinding binding,
  double newStart,
  double newEnd,
  String? mergeGroup,
) {
  if (binding.isSfx) return const VideoLaneEdit.refused('A sound effect has no trim.');
  final leftDelta = newStart.round() - binding.span.start;
  if (leftDelta == 0 && newEnd.round() == binding.span.end) return null;
  final trimFrom = binding.trimFromFrames;
  if (leftDelta != 0) {
    if (trimFrom == null) {
      return const VideoLaneEdit.refused('Trim the end first; the source length is not known yet.');
    }
    final from = (trimFrom + leftDelta).clamp(0, binding.trimToFrames! - 1);
    if (from == trimFrom) return null;
    return VideoLaneEdit.command(
      _trimCommand(binding, from: from, to: binding.trimToFrames!, mergeGroup: mergeGroup),
    );
  }
  final length = (newEnd.round() - binding.span.start).clamp(1, 1 << 31);
  final from = trimFrom ?? 0;
  return VideoLaneEdit.command(
    _trimCommand(binding, from: from, to: from + length, mergeGroup: mergeGroup),
  );
}

SetAudioTrackCommand _trimCommand(
  VideoAudioLaneBinding binding, {
  required int from,
  required int to,
  required String? mergeGroup,
}) => SetAudioTrackCommand(
  scene: binding.scene,
  index: binding.index,
  patch: {
    'trim': {'from': '${from}f', 'to': '${to}f'},
  },
  mergeGroup: mergeGroup,
);

({int start, int length}) _ownerOf(VideoLaneModel model, VideoAudioLaneBinding binding) {
  final scene = binding.scene;
  if (scene == null) return (start: 0, length: model.totalFrames);
  final span = model.timebase.sceneSpans[scene];
  return (start: span.start, length: span.durationFrames);
}
