import 'dart:io';

import 'package:slides/loader/recent_deck.dart';
import 'package:slides/loader/recent_decks_store.dart';

/// The desktop recents store.
RecentDecksStore platformRecentDecksStore() => IoRecentDecksStore();

/// Desktop recents: a JSON file under the user's config directory
/// (`$XDG_CONFIG_HOME`, falling back to `$HOME/.config`).
final class IoRecentDecksStore implements RecentDecksStore {
  /// Creates the store over [path]; without one, the default config-file
  /// location derived from [environment] (the process environment).
  IoRecentDecksStore({String? path, Map<String, String>? environment})
    : path = path ?? _defaultPath(environment ?? Platform.environment);

  /// Where the list lives.
  final String path;

  static String _defaultPath(Map<String, String> environment) {
    final base = environment['XDG_CONFIG_HOME'] ?? '${environment['HOME'] ?? '.'}/.config';
    return '$base/fluvie_slides/recent_decks.json';
  }

  @override
  Future<List<RecentDeck>> load() async {
    try {
      return decodeRecentDecks(await File(path).readAsString());
    } on IOException {
      return const [];
    }
  }

  @override
  Future<void> record(RecentDeck deck, {RecentDeck? replacing}) async {
    final next = upsertRecents(await load(), deck, replacing: replacing);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(encodeRecentDecks(next));
  }
}
