part of 'slides_app.dart';

/// The shell's start-screen preferences: what the open screen remembers
/// between sessions. Lives outside the state class, like the recents
/// bookkeeping; `_refresh` keeps `setState` inside it.
extension _SlidesAppPrefs on _SlidesAppState {
  /// Reads the stored preferences once at boot. Until they arrive the tips
  /// stay hidden, so a returning user never sees the card flash.
  Future<void> _loadStartPrefs() async {
    final prefs = await _startPrefs.load();
    if (mounted) _refresh(() => _tipsDismissed = prefs.tipsDismissed);
  }

  /// Puts the tips card away now and remembers it for next time.
  void _dismissTips() {
    _refresh(() => _tipsDismissed = true);
    unawaited(_startPrefs.save(const StartPrefs(tipsDismissed: true)));
  }
}
