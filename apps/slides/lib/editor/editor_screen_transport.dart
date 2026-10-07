part of 'editor_screen.dart';

/// The editor's slide navigation and the shared playhead: stepping between
/// slides, swapping the transport as each arrives settled, and presenting
/// the document as it stands. Lives outside the state class; `_refresh`
/// keeps `setState` inside it.
extension _EditorScreenTransport on _EditorScreenState {
  void _step(int delta) => _showSlide(_slide + delta);

  /// Puts [slide] on stage (the registry's slide commands follow their
  /// result through this), clamped to the deck. A change swaps the shared
  /// transport for a fresh one — every slide arrives settled. The retired
  /// transport disposes after the frame that unmounts its player, so a
  /// last in-flight tick never hits a dead clock.
  void _showSlide(int slide) {
    final next = slide.clamp(0, _history.document.sceneCount - 1);
    if (next == _slide) return;
    final retired = _transport;
    WidgetsBinding.instance.addPostFrameCallback((_) => retired.dispose());
    _refresh(() {
      _slide = next;
      _transport = _createTransport(next);
    });
    _syncAudioPreview();
  }

  /// Space's step past the last landing: the next slide, arriving on its
  /// base landing (the presenter's base step held state).
  void _stepIntoNextSlide() {
    final next = _slide + 1;
    if (next >= _history.document.sceneCount) return;
    _showSlide(next);
    final bounds = slideStepBounds(_history.document, next);
    if (bounds.isNotEmpty) _transport.seek(bounds.first);
  }

  /// Undo or redo, then re-select what the step touched so it is visible.
  void _travel(Set<String> Function() move) {
    final touched = move();
    // An undone insertion reports the removed ids too. Selection must describe
    // the restored document, otherwise the inspector retains a phantom target.
    _selectionScope.read(selectionProvider.notifier).select({
      for (final id in touched)
        if (_history.document.elementJson(id) != null) id,
    });
  }

  /// Presents the document as it is right now, over the editor; closing
  /// the presentation lands back here with every edit intact. Any pending
  /// autosave flushes first — a crash mid-presentation loses nothing.
  ///
  /// The speaker copy travels with its `bundle` values rewritten to this
  /// window's session URLs (see `speakerDeckPayload`), so a bundle deck
  /// presents in the popup too; the document itself keeps its references.
  void _present() {
    unawaited(_autosave.flush());
    _transport.pause();
    _videoTransport?.pause();
    _audioPreview.stopAudition();
    final document = _history.document;
    final store = widget.storeSpeaker ?? storeSpeakerDeck;
    store(
      kind: 'file',
      payload: jsonEncode(speakerDeckPayload(document.toJson(), urlFor: _speakerUrlFor)),
    );
    _refresh(() => _presenting = document.spec.build());
  }

  /// The popup-readable URL for one session value, or null when the session
  /// no longer holds it (the payload rewrite then falls back honestly).
  String? _speakerUrlFor(String value) {
    final bytes = _sessionMedia.bytesFor(value);
    if (bytes == null) return null;
    return (widget.speakerMediaUrl ?? sessionMediaUrl)(value, bytes);
  }
}
