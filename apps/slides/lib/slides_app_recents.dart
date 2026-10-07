part of 'slides_app.dart';

/// The shell's recents bookkeeping: loading the list, recording opens and
/// saves, and reopening entries by path. Lives outside the state class;
/// `_refresh` keeps `setState` inside it.
extension _SlidesAppRecents on _SlidesAppState {
  Future<void> _reloadRecents() async {
    final loaded = await _recents.load();
    if (mounted) _refresh(() => _recentDecks = loaded);
  }

  Future<void> _record(RecentDeck deck, {RecentDeck? replacing}) async {
    await _recents.record(deck, replacing: replacing);
    await _reloadRecents();
  }

  Future<void> _editFile() async {
    final loaded = await widget.openFile();
    if (loaded == null || !mounted) return;
    await _editLoaded(loaded);
  }

  /// Opens [loaded] in the editor and remembers it as a recent deck.
  Future<void> _editLoaded(LoadedDeck loaded) async {
    final raw = loaded.rawJson;
    if (raw == null) {
      _refresh(() => _loadError = '${loaded.name}: ${loaded.error}');
      return;
    }
    final recent = RecentDeck(name: loaded.name, path: loaded.path, lastOpened: DateTime.now());
    if (await _editDocument(loaded.name, parseRawJson(raw), recent: recent)) {
      await _record(recent);
    }
  }

  Future<void> _openRecent(RecentDeck deck) async {
    final path = deck.path;
    if (path == null) return;
    final loaded = await widget.openPath(path);
    if (!mounted) return;
    await _editLoaded(loaded);
  }

  /// A save (or a rename once the deck has an identity) refreshes the
  /// deck's recents entry, replacing the previous one.
  Future<void> _deckTouched(String name, String? path, {required bool renameOnly}) async {
    final previous = _editingRecent;
    if (renameOnly && previous == null) return;
    final next = RecentDeck(name: name, path: path ?? previous?.path, lastOpened: DateTime.now());
    _editingRecent = next;
    await _record(next, replacing: previous);
  }
}
