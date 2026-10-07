import 'package:slides/loader/recent_deck.dart';
import 'package:slides/loader/recent_decks_store.dart';

/// An in-memory recents store (what localStorage or the desktop sidecar
/// hold). Every test that mounts the shell injects one so no run reads the
/// developer's real config directory.
final class MemoryRecents implements RecentDecksStore {
  /// Creates a store that starts out holding [entries], most recent first.
  MemoryRecents([List<RecentDeck> entries = const []]) : entries = [...entries];

  /// The remembered decks, most recent first.
  List<RecentDeck> entries;

  @override
  Future<List<RecentDeck>> load() async => entries;

  @override
  Future<void> record(RecentDeck deck, {RecentDeck? replacing}) async {
    entries = upsertRecents(entries, deck, replacing: replacing);
  }
}
