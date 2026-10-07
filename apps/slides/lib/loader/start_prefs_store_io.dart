import 'dart:io';

import 'package:slides/loader/start_prefs_store.dart';

/// The desktop start-screen preferences store.
StartPrefsStore platformStartPrefsStore() => IoStartPrefsStore();

/// Desktop start-screen preferences: a JSON file under the user's config
/// directory (`$XDG_CONFIG_HOME`, falling back to `$HOME/.config`).
final class IoStartPrefsStore implements StartPrefsStore {
  /// Creates the store over [path]; without one, the default config-file
  /// location derived from [environment] (the process environment).
  IoStartPrefsStore({String? path, Map<String, String>? environment})
    : path = path ?? _defaultPath(environment ?? Platform.environment);

  /// Where the preferences live.
  final String path;

  static String _defaultPath(Map<String, String> environment) {
    final base = environment['XDG_CONFIG_HOME'] ?? '${environment['HOME'] ?? '.'}/.config';
    return '$base/fluvie_slides/start_prefs.json';
  }

  @override
  Future<StartPrefs> load() async {
    try {
      return decodeStartPrefs(await File(path).readAsString());
    } on IOException {
      return const StartPrefs();
    }
  }

  @override
  Future<void> save(StartPrefs prefs) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(encodeStartPrefs(prefs));
  }
}
