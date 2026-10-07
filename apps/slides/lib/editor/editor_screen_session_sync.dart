part of 'editor_screen.dart';

extension _EditorScreenSessionSync on _EditorScreenState {
  /// The session bytes the document references right now — what an autosave
  /// packs beside the record so a crash cannot orphan a session-media deck.
  /// A value the session no longer holds is skipped (best-effort, like the
  /// rest of autosave); the recovery prompt owns that honesty.
  Map<String, Uint8List> _referencedSessionBytes() => {
    for (final value in documentBundleValues(_history.document))
      value: ?_sessionMedia.bytesFor(value),
  };
  void _syncAudioPreview() {
    _audioPreview
      ..updateDocument(_history.document)
      ..bindTransport(
        _videoMode ? _videoTransport! : _transport,
        absoluteOffset: _videoMode ? 0 : _videoTimebase.sceneSpans[_slide].start,
      );
  }

  /// The master on the stage in master-edit mode, or null in the normal
  /// deck view. A master that disappeared (an undone New master) exits the
  /// mode by reading as null.
  String? get _editingMasterName {
    final name = _editingMaster;
    return name != null && _history.document.masterNames.contains(name) ? name : null;
  }

  void _documentChanged() {
    _autosave.changed();
    // Undoing a slide insert while standing on it leaves the stage past
    // the deck's end: clamp back onto the last slide (fresh transport).
    if (_slide >= _history.document.sceneCount) {
      final retired = _transport;
      WidgetsBinding.instance.addPostFrameCallback((_) => retired.dispose());
      _slide = _history.document.sceneCount - 1;
      _transport = _createTransport(_slide);
    }
    final fps = _history.document.spec.fps;
    if (_transport.fps != fps) {
      final retired = _transport;
      _transport = _createTransport(_slide)..seek((retired.frame * fps / retired.fps).round());
      WidgetsBinding.instance.addPostFrameCallback((_) => retired.dispose());
    }
    _syncVideoTransport();
    _syncAudioPreview();
    _refresh(() {});
  }

  void _queueChanged() {
    if (!_quickExported && _renderQueue.jobs.any((job) => job.phase == RenderQueuePhase.complete)) {
      _refresh(() => _quickExported = true);
    }
  }

  void _autosaveChanged() {
    if (mounted) _refresh(() {});
  }
}
