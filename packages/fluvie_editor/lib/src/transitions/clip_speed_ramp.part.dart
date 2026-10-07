part of 'clip_speed_edit.dart';

double _consumed(Map<String, Object?> element, int fps, int frames) {
  final ramp = KeyframedNumber.maybeFromJson(element['speed']);
  return ramp == null
      ? frames * clipSpeedOf(element).abs() / fps
      : integrateClipSpeedRamp(ramp, fps: fps, windowFrames: frames).last;
}

/// Edits a positive speed ramp while preserving source in/out. Duration follows
/// the integral of its rates; explicit [durationFrames] rate-stretches the whole
/// curve. Sub-frame rounding scales rates uniformly to consume the exact trim.
VideoLaneEdit clipSpeedRampEdited(
  EditorDocument document,
  String id,
  KeyframedNumber ramp, {
  int? durationFrames,
  String? mergeGroup,
}) {
  final element = document.elementJson(id);
  if (element == null || element['type'] != 'Clip') {
    return const VideoLaneEdit.refused('Select a clip for a speed ramp.');
  }
  if (document.spec.lanes.any((lane) => lane.id == element['lane'] && lane.locked)) {
    return const VideoLaneEdit.refused('Unlock the lane before changing speed.');
  }
  if (element['shared'] != null) {
    return _sharedSpeedEdited(
      document,
      id,
      (local, member) => clipSpeedRampEdited(local, member, ramp, durationFrames: durationFrames),
      mergeGroup: mergeGroup,
    );
  }
  final trim = readClipTrimSeconds(element);
  if (trim == null) return const VideoLaneEdit.refused(clipTrimUnitNote);
  try {
    final timeline = introspectTimeline(document.spec.build());
    final span = videoElementOwner(document, timeline, id);
    final fps = document.spec.fps;
    final scope = OwnerFrameScope(fps, span);
    final show = element['show'] as Map<String, Object?>?;
    final from = show?['from'] == null ? 0 : decodeTime(show!['from']).resolveFrames(scope);
    final to = show?['to'] == null
        ? span.durationFrames
        : decodeTime(show!['to']).resolveFrames(scope);
    final consumed = trim.toOpen ? _consumed(element, fps, to - from) : trim.to - trim.from;
    final capacity = span.durationFrames - from;
    var duration = durationFrames;
    if (duration == null) {
      if (ramp.positions.every((position) => position is RelativeTime && position.max == null)) {
        final mean = integrateClipSpeedRamp(ramp, fps: 1024, windowFrames: 1024).last;
        duration = (consumed * fps / mean).round();
      } else {
        var lo = 2;
        var hi = capacity;
        if (integrateClipSpeedRamp(ramp, fps: fps, windowFrames: hi).last < consumed) {
          return const VideoLaneEdit.refused('The speed ramp needs a longer scene or group.');
        }
        while (lo < hi) {
          final mid = (lo + hi) ~/ 2;
          if (integrateClipSpeedRamp(ramp, fps: fps, windowFrames: mid).last < consumed) {
            lo = mid + 1;
          } else {
            hi = mid;
          }
        }
        duration = lo;
      }
    }
    if (duration < 2 || duration > capacity) {
      return const VideoLaneEdit.refused(
        'The speed ramp does not fit inside its scene or group. Extend the scene first.',
      );
    }
    final total = integrateClipSpeedRamp(ramp, fps: fps, windowFrames: duration).last;
    final fitted = KeyframedNumber(
      values: [for (final value in ramp.values) value * consumed / total],
      positions: ramp.positions,
      easings: ramp.easings,
    );
    final command = ReplaceElementCommand(
      id: id,
      element: {
        ...element,
        'speed': fitted.toJson(),
        'show': {'from': '${from}f', 'to': '${from + duration}f'},
        'trim': trimSecondsJson(trim.from, trim.from + consumed),
      },
      mergeGroup: mergeGroup,
    )..apply(document);
    return VideoLaneEdit.command(command);
  } on Object catch (error) {
    return VideoLaneEdit.refused('Speed ramp refused: $error');
  }
}
