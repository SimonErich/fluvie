import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/foundation.dart' show immutable;
import 'package:slides/loader/start_prefs_store_io.dart'
    if (dart.library.js_interop) 'package:slides/loader/start_prefs_store_web.dart';

/// What the start screen remembers between sessions.
///
/// One flag today; the JSON shape leaves room for more without a migration,
/// because an absent key always reads as its default.
@immutable
final class StartPrefs {
  /// Describes one stored preference set.
  const StartPrefs({this.tipsDismissed = false});

  /// Reads one stored preference set; anything but a literal `true` reads as
  /// "not dismissed", so a half-written file never hides the tips.
  factory StartPrefs.fromJson(Map<String, Object?> json) =>
      StartPrefs(tipsDismissed: json['tipsDismissed'] == true);

  /// Whether the user dismissed the first-run tips card.
  final bool tipsDismissed;

  /// The JSON form the stores persist.
  Map<String, Object?> toJson() => {'tipsDismissed': tipsDismissed};
}

/// Where the start screen's preferences live: a small JSON file under the
/// user's config directory on desktop, localStorage on the web.
abstract interface class StartPrefsStore {
  /// The store for the running platform.
  factory StartPrefsStore.platform() => platformStartPrefsStore();

  /// The stored preferences. Unreadable storage reads as the defaults.
  Future<StartPrefs> load();

  /// Persists [prefs], replacing whatever was stored.
  Future<void> save(StartPrefs prefs);
}

/// The stored text form of [prefs].
String encodeStartPrefs(StartPrefs prefs) => jsonEncode(prefs.toJson());

/// Parses stored preferences; anything unreadable (garbage, foreign JSON, an
/// empty blob) reads as the defaults rather than crashing the start screen.
StartPrefs decodeStartPrefs(String? text) {
  if (text == null || text.isEmpty) return const StartPrefs();
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    return const StartPrefs();
  }
  if (decoded is! Map<String, Object?>) return const StartPrefs();
  return StartPrefs.fromJson(decoded);
}
