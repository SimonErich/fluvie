part of 'video_lane_model.dart';

/// The effect rows of one element: one row per entry of its `effects` list,
/// each bar spanning the element's own window (an effect has no span of its
/// own), with a diamond per stop of every keyframed parameter.
extension _VideoEffectRows on _VideoLaneBuilder {
  /// Appends the effect rows for element [id] right after its bar was
  /// placed. Under the element's own row they indent one level and read as
  /// its children; when the element's bar sits on a declared lane there is
  /// no parent row, so each carries the element's name instead.
  void _effectRows(String id, Map<String, Object?> json, FrameSpan window) {
    final effects = json['effects'];
    if (effects is! List) return;
    final onDeclaredLane =
        json['lane'] is String &&
        tracks.any((track) => track.id == laneRowId(json['lane']! as String));
    for (var index = 0; index < effects.length; index++) {
      final effect = effects[index];
      if (effect is! Map<String, Object?>) continue;
      final kind = effect['kind'] as String? ?? '?';
      final barId = 'fx:$id:$index';
      final stopFramesByParam = <String, List<int>>{};
      final diamonds = <TimelineDiamond>[];
      // Only the kind's own numeric parameters can be keyframed: a shader
      // author is free to name a uniform "values", and that names a float
      // slot, not a ramp.
      final numeric = {
        for (final specKind in EffectSpecKind.values)
          if (specKind.name == kind)
            for (final param in specKind.params) param.name,
      };
      for (final entry in effect.entries) {
        if (!numeric.contains(entry.key)) continue;
        final stopFrames = keyframedValueStopFrames(
          entry.value,
          spanFrames: window.durationFrames,
          fps: timebase.fps,
        );
        if (stopFrames == null) continue;
        stopFramesByParam[entry.key] = stopFrames;
        for (var stop = 0; stop < stopFrames.length; stop++) {
          final diamondId = '$barId:${entry.key}:k$stop';
          diamonds.add(
            TimelineDiamond(id: diamondId, frame: (window.start + stopFrames[stop]).toDouble()),
          );
          effectDiamonds[diamondId] = VideoEffectDiamondBinding(
            elementId: id,
            effectIndex: index,
            param: entry.key,
            stop: stop,
          );
        }
      }
      tracks.add(
        TimelineTrack(
          id: 'fx-track:$id:$index',
          label: onDeclaredLane ? '${_elementLabel(id, json)} · $kind' : kind,
          depth: onDeclaredLane ? 0 : 1,
          bars: [
            TimelineBar(
              id: barId,
              start: window.start.toDouble(),
              end: window.end.toDouble(),
              color: palette.element,
              badge: kind,
              diamonds: diamonds,
            ),
          ],
        ),
      );
      effectBars[barId] = VideoEffectLaneBinding(
        elementId: id,
        effectIndex: index,
        window: window,
        stopFramesByParam: stopFramesByParam,
      );
    }
  }
}
