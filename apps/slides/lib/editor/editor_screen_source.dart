part of 'editor_screen.dart';

/// Places the marked source range at the current edit clock. Source marks
/// use the asset rate; timeline windows use the document rate.
extension _EditorScreenSource on _EditorScreenState {
  void _placeSourceRange(SourceMonitorPlacement placement, {String? lane, int? atFrame}) {
    final document = _history.document;
    final entry = placement.entry;
    lane ??= _selectionScope.read(activeTimelineLaneProvider);
    final targetLane = document.spec.lanes.where((candidate) => candidate.id == lane).firstOrNull;
    if (targetLane != null && targetLane.locked) {
      unawaited(
        _showFileMessage('Cannot place source', 'Unlock the selected lane before placing media.'),
      );
      return;
    }
    if (targetLane != null &&
        (targetLane.kind.name == 'audio') != (entry.kind == MediaStoreKind.audio)) {
      unawaited(
        _showFileMessage(
          'Cannot place source',
          entry.kind == MediaStoreKind.audio
              ? 'Select an audio lane for this source.'
              : 'Select a video lane for this source.',
        ),
      );
      return;
    }
    final sourceFps = entry.fps ?? document.spec.fps.toDouble();
    final fromSeconds = placement.start / sourceFps;
    final toSeconds = placement.end / sourceFps;
    final absolute =
        atFrame ??
        _videoTransport?.frame ??
        _videoTimebase.sceneSpans[_slide].start + _transport.frame;
    final scene = _videoMode ? _videoTimebase.sceneAt(absolute) : _slide;
    final span = _videoTimebase.sceneSpans[scene];
    final start = (absolute - span.start).clamp(0, span.durationFrames - 1);
    final length = entry.kind == MediaStoreKind.image
        ? span.durationFrames - start
        : ((toSeconds - fromSeconds) * document.spec.fps).round().clamp(
            1,
            span.durationFrames,
          );
    final end = (start + length).clamp(start + 1, span.durationFrames);
    final trim = {
      'from': '${fromSeconds}s',
      'to': '${fromSeconds + (end - start) / document.spec.fps}s',
    };
    if (entry.kind == MediaStoreKind.audio) {
      _history.dispatch(
        AddAudioTrackCommand(
          scene: scene,
          track: {
            'kind': 'music',
            'lane': ?lane,
            'source': entry.source,
            'loop': false,
            'at': {'kind': 'at', 'time': '${start}f'},
            'trim': trim,
          },
        ),
      );
      return;
    }
    final id = document.nextId();
    _history.dispatch(
      InsertElementCommand(
        scene: scene,
        id: id,
        element: {
          'lane': ?lane,
          'type': entry.kind == MediaStoreKind.video ? 'Clip' : 'Image',
          'source': entry.source,
          'fit': 'contain',
          'transform': const {'x': 0.5, 'y': 0.5, 'w': 1.0, 'h': 1.0},
          'show': {'from': '${start}f', 'to': '${end}f'},
          if (entry.kind == MediaStoreKind.video) 'trim': trim,
        },
      ),
    );
    _selectionScope.read(selectionProvider.notifier).select({id});
  }
}
