part of 'editor_screen.dart';

/// The editor's file operations: save (plain JSON or a media bundle), Save
/// as, Save a copy, rename, and the guarded close. Lives outside the state
/// class; `_refresh` keeps `setState` inside it.
extension _EditorScreenFiles on _EditorScreenState {
  String get _contents => const JsonEncoder.withIndent('  ').convert(_history.document.toJson());

  /// The quiet indicator's text: "Saving…" while a write is in flight,
  /// then "Saved", `Autosaved <when>` once the debounce has the current
  /// state covered, or "Unsaved".
  String get _saveStatus {
    if (_saving) return 'Saving…';
    if (!_dirty) return 'Saved';
    final at = _autosave.lastAutosaveAt;
    if (at != null && _autosave.lastAutosaveDigest == _history.document.documentDigest) {
      return 'Autosaved ${relativeTimeLabel(at, _autosave.now())}';
    }
    return 'Unsaved';
  }

  /// Save: plain JSON when the deck references no session media; otherwise
  /// the media dialog decides (bundle, JSON with the suppressible warning,
  /// or the remembered per-deck choice).
  Future<void> _save({bool pickNew = false}) async {
    final referenced = documentBundleValues(_history.document);
    if (referenced.isEmpty) return _savePlain(pickNew: pickNew);
    switch (_history.document.deckMeta['mediaSave']) {
      case 'json':
        return _savePlain(pickNew: pickNew);
      case 'bundle':
        return _saveBundle(referenced, pickNew: pickNew);
    }
    final choice = await _askMediaSave(referenced.length);
    if (choice == null || !mounted) return;
    if (choice.remember) {
      _history.dispatch(SetDeckMetaCommand(meta: {'mediaSave': choice.bundle ? 'bundle' : 'json'}));
    }
    return choice.bundle ? _saveBundle(referenced, pickNew: pickNew) : _savePlain(pickNew: pickNew);
  }

  Future<void> _savePlain({required bool pickNew}) async {
    final document = _history.document;
    _refresh(() => _saving = true);
    try {
      final contents = _portableContents;
      final name = await _saver.save(
        suggestedName: _name,
        contents: contents,
        pickNew: pickNew,
      );
      if (name == null || !mounted) return;
      // A fresh pick reveals the target only now: settle the file with the
      // paths rewritten relative to its folder (a silent second write).
      final settled = _portableContents;
      if (settled != contents) {
        await _saver.save(suggestedName: _name, contents: settled);
      }
      await _finishSave(document, name);
    } finally {
      if (mounted) _refresh(() => _saving = false);
    }
  }

  /// The document JSON with file media under the save target's folder
  /// rewritten relative to it — the portable desktop form. Without a known
  /// target (the web, before the first pick) this is [_contents] verbatim.
  String get _portableContents {
    final target = _saver.targetPath;
    final directory = target == null ? null : directoryOfPath(target);
    if (directory == null) return _contents;
    return const JsonEncoder.withIndent('  ').convert(
      deckJsonWithRelativeMediaPaths(
        _history.document.toJson(),
        documentDirectory: directory,
        base: MediaFileBase.current,
      ),
    );
  }

  /// Packs the deck JSON plus every referenced session byte into a bundle.
  /// Missing session bytes fail visibly: nothing is written.
  Future<void> _saveBundle(Set<String> referenced, {required bool pickNew}) async {
    final document = _history.document;
    final media = <String, Uint8List>{};
    final missing = <String>[];
    for (final value in referenced) {
      final bytes = _sessionMedia.bytesFor(value);
      bytes == null ? missing.add(value) : media[value] = bytes;
    }
    if (missing.isNotEmpty) {
      return _showFileMessage(
        'Cannot save the bundle',
        'This deck references imported media the session no longer holds: '
            '${(missing.toList()..sort()).join(', ')}. Re-import it, then save again.',
      );
    }
    _refresh(() => _saving = true);
    try {
      final name = await _saver.saveBundle(
        suggestedName: _name,
        bytes: buildFluvieBundle(deckJson: _contents, media: media),
        pickNew: pickNew,
      );
      if (name == null || !mounted) return;
      await _finishSave(document, name);
    } finally {
      if (mounted) _refresh(() => _saving = false);
    }
  }

  /// A completed save's bookkeeping: the title, the clean digest, the
  /// covered autosave, and the host's recents entry.
  Future<void> _finishSave(EditorDocument document, String name) async {
    _refresh(() {
      _name = name;
      _savedDigest = document.documentDigest;
    });
    await _autosave.saved(_saver.targetPath ?? name);
    widget.onDeckSaved?.call(name, _saver.targetPath);
  }

  /// Writes the document to a fresh target and forgets about it: the open
  /// document keeps its name, its saver target, and its dirty state. A deck
  /// with session media warns first — a JSON copy cannot carry it.
  Future<void> _saveCopy() async {
    if (documentBundleValues(_history.document).isNotEmpty) {
      final anyway = await _confirmMediaLessCopy();
      if (anyway != true || !mounted) return;
    }
    _refresh(() => _saving = true);
    try {
      await _saver.saveCopy(suggestedName: _name, contents: _contents);
    } finally {
      if (mounted) _refresh(() => _saving = false);
    }
  }

  void _rename(String next) {
    _refresh(() => _name = next);
    widget.onDeckRenamed?.call(next, _saver.targetPath);
  }

  Future<void> _close() async {
    if (!_dirty) {
      // A pending debounce on a clean document is a stale record's clear;
      // run it so an orderly exit leaves nothing to "recover".
      await _autosave.flush();
      if (mounted) widget.onClose();
      return;
    }
    final discard = await OiDialogShell.show<bool>(
      context: context,
      semanticLabel: 'Discard changes?',
      maxWidth: 480,
      minWidth: 280,
      builder: (close) => OiDialog.standard(
        label: 'Discard changes?',
        title: 'Discard changes?',
        content: OiLabel.body('"$_name" has unsaved changes.'),
        actions: [
          OiButton.secondary(label: 'Cancel', onTap: () => close(false)),
          OiButton.primary(label: 'Discard', onTap: () => close(true)),
        ],
        onClose: () => close(false),
      ),
    );
    if ((discard ?? false) && mounted) {
      // Discarding is explicit: the changes go, and their autosave with
      // them.
      await _autosave.discard();
      if (mounted) widget.onClose();
    }
  }
}
