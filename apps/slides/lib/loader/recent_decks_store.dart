import 'package:slides/loader/recent_deck.dart';
import 'package:slides/loader/recent_decks_store_io.dart'
    if (dart.library.js_interop) 'package:slides/loader/recent_decks_store_web.dart';

/// Keeps the open screen's recent-decks list: a small JSON file under the
/// user's config directory on desktop, localStorage on the web.
abstract interface class RecentDecksStore {
  /// The store for the running platform.
  factory RecentDecksStore.platform() => platformRecentDecksStore();

  /// The remembered decks, most recent first. Unreadable storage reads as
  /// empty.
  Future<List<RecentDeck>> load();

  /// Upserts [deck] at the front (dedup by path, then name; capped). A
  /// non-null [replacing] drops that older identity first — how a rename
  /// replaces its old entry.
  Future<void> record(RecentDeck deck, {RecentDeck? replacing});
}

/// The pure upsert both stores share: [deck] lands first, its own identity
/// and [replacing]'s leave the list, and the list caps at [cap] entries.
List<RecentDeck> upsertRecents(
  List<RecentDeck> current,
  RecentDeck deck, {
  RecentDeck? replacing,
  int cap = 8,
}) {
  final kept = [
    for (final entry in current)
      if (entry.key != deck.key && entry.key != replacing?.key) entry,
  ];
  return [deck, ...kept.take(cap - 1)];
}
