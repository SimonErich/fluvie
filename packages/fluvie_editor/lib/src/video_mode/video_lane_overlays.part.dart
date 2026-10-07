part of 'video_lane_model.dart';

extension _VideoLaneOverlays on _VideoLaneBuilder {
  /// One bar per overlay, spanning its window across the whole ruler.
  ///
  /// No scene span and no clamp: an overlay's window is measured against the
  /// video, so its bar crosses every boundary without a seam. There is no
  /// slide for it to be pulled back into.
  void _overlayLanes() {
    for (final id in document.overlayIds) {
      final json = document.elementJson(id) ?? const {};
      final window = _overlayWindow(json);
      final barId = 'overlay:$id';
      _place(
        laneId: json['lane'] is String ? json['lane']! as String : null,
        ownRowId: 'overlay-track:$id',
        label: _elementLabel(id, json),
        bar: TimelineBar(
          id: barId,
          start: window.start.toDouble(),
          end: window.end.toDouble(),
          color: palette.element,
          badge: _elementLabel(id, json),
        ),
      );
      overlayBars[barId] = VideoOverlayLaneBinding(
        elementId: id,
        window: window,
        home: document.overlayHome(id),
      );
      _effectRows(id, json, window);
    }
  }

  /// An overlay's window in absolute frames, defaulting to the whole video.
  FrameSpan _overlayWindow(Map<String, Object?> json) {
    final show = json['show'];
    if (show is! Map<String, Object?>) return FrameSpan(0, timebase.totalFrames);
    final scope = OwnerFrameScope(timebase.fps, FrameSpan(0, timebase.totalFrames));
    final from = show['from'] == null ? 0 : decodeTime(show['from']).resolveFrames(scope);
    final to = show['to'] == null
        ? timebase.totalFrames
        : decodeTime(show['to']).resolveFrames(scope);
    return FrameSpan(from, to.clamp(from + 1, timebase.totalFrames));
  }
}
