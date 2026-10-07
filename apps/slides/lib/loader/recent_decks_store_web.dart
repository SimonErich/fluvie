// Browser-only glue: exercised by hand and compiled by the web_build CI
// job; tests inject fakes through the seam in `recent_decks_store.dart`.
// coverage:ignore-file
import 'package:slides/loader/recent_deck.dart';
import 'package:slides/loader/recent_decks_store.dart';
import 'package:web/web.dart' as web;

/// The web recents store.
RecentDecksStore platformRecentDecksStore() => _WebRecentDecksStore();

/// Web recents: the list rides localStorage. Entries carry names and
/// timestamps only — the browser has no reopenable paths, so the picker
/// shows them as plain history.
final class _WebRecentDecksStore implements RecentDecksStore {
  static const _key = 'fluvie_recent_decks';

  @override
  Future<List<RecentDeck>> load() async => decodeRecentDecks(web.window.localStorage.getItem(_key));

  @override
  Future<void> record(RecentDeck deck, {RecentDeck? replacing}) async {
    final next = upsertRecents(await load(), deck, replacing: replacing);
    web.window.localStorage.setItem(_key, encodeRecentDecks(next));
  }
}
