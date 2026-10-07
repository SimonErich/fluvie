// Browser-only glue: exercised by hand and compiled by the web_build CI
// job; tests inject fakes through the seam in `start_prefs_store.dart`.
// coverage:ignore-file
import 'package:slides/loader/start_prefs_store.dart';
import 'package:web/web.dart' as web;

/// The web start-screen preferences store.
StartPrefsStore platformStartPrefsStore() => _WebStartPrefsStore();

/// Web start-screen preferences: one small blob in localStorage. It holds a
/// single boolean, so it stays far under the shared origin quota.
final class _WebStartPrefsStore implements StartPrefsStore {
  static const _key = 'fluvie_slides_start_prefs';

  @override
  Future<StartPrefs> load() async => decodeStartPrefs(web.window.localStorage.getItem(_key));

  @override
  Future<void> save(StartPrefs prefs) async =>
      web.window.localStorage.setItem(_key, encodeStartPrefs(prefs));
}
