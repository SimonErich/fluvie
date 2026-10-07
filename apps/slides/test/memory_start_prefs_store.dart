import 'package:slides/loader/start_prefs_store.dart';

/// An in-memory start-screen preferences store (what the config file or
/// localStorage hold). Every test that mounts the shell injects one so no
/// test reads or writes the developer's real config directory.
final class MemoryStartPrefsStore implements StartPrefsStore {
  /// Creates a store that starts out holding [prefs].
  MemoryStartPrefsStore([this.prefs = const StartPrefs()]);

  /// The stored preferences.
  StartPrefs prefs;

  /// How many saves happened.
  int saves = 0;

  @override
  Future<StartPrefs> load() async => prefs;

  @override
  Future<void> save(StartPrefs prefs) async {
    saves++;
    this.prefs = prefs;
  }
}
