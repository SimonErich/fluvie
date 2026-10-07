part of 'slides_app.dart';

/// The shell's deck-opening flow: opening a document for editing, and
/// presenting one (bundled, from the picker, or dropped). Lives outside the
/// state class; `_refresh` keeps `setState` inside it.
extension _SlidesAppOpen on _SlidesAppState {
  /// Opens [json] for editing, first offering any newer autosave stored
  /// under the deck's key (its path when it has one, [title] otherwise).
  Future<bool> _editDocument(String title, Map<String, Object?> json, {RecentDeck? recent}) async {
    // A document with no file on disk (blank, template, demo) has no folder
    // for relative media to resolve against, so any base a prior file open
    // left behind clears here. A file or recent open (recent != null) keeps
    // the base the loader just scoped to its own directory.
    if (recent == null) MediaFileBase.current = null;
    final EditorDocument document;
    try {
      document = EditorDocument.fromJson(json);
    } on Object catch (error) {
      _refresh(() => _loadError = '$title: $error');
      return false;
    }
    final key = recent?.path ?? title;
    final recovered = await _maybeRecover(key, title, document);
    if (!mounted) return false;
    _refresh(() {
      _editing = (
        document: recovered ?? document,
        title: title,
        key: key,
        // A recovered document differs from the file, so it opens unsaved
        // against the file's own digest.
        savedDigest: recovered == null ? null : document.documentDigest,
      );
      _editingRecent = recent;
      _loadError = null;
    });
    return true;
  }

  void _presentBundled(DeckEntry deck) {
    _storeSpeaker(kind: 'bundled', payload: deck.id);
    _refresh(() {
      _presenting = deck.build();
      _loadError = null;
    });
  }

  Future<void> _presentFile() async {
    final loaded = await widget.openFile();
    if (loaded == null || !mounted) return;
    _presentLoaded(loaded);
  }

  void _presentLoaded(LoadedDeck loaded) {
    if (loaded.video == null) {
      _refresh(() => _loadError = '${loaded.name}: ${loaded.error}');
      return;
    }
    // The speaker copy rewrites bundle references to this window's session
    // URLs, so a bundle deck presents in the popup too (see
    // speakerDeckPayload). A deck without them passes through verbatim.
    final json = jsonDecode(loaded.rawJson!) as Map<String, Object?>;
    _storeSpeaker(
      kind: 'file',
      payload: jsonEncode(speakerDeckPayload(json, urlFor: _speakerUrlFor)),
    );
    _refresh(() {
      _presenting = loaded.video;
      _loadError = null;
    });
  }

  /// The popup-readable URL for one session value, or null when the session
  /// does not hold it (the rewrite then falls back to the asset form).
  String? _speakerUrlFor(String value) {
    final bytes = _sessionMedia.bytesFor(value);
    if (bytes == null) return null;
    return sessionMediaUrl(value, bytes);
  }
}

/// The presentation screen the shell swaps in while a deck is playing.
final class _PresentingScreen extends StatelessWidget {
  const _PresentingScreen({required this.video, required this.onClose});

  final Video video;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => FluvieSlides(video, onClose: onClose);
}
