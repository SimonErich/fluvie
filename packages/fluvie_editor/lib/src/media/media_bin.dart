import 'package:flutter/foundation.dart' show immutable;
import 'package:fluvie_editor/src/media/media_store_entry.dart';

/// How a bin listing is ordered.
enum MediaBinSort {
  /// By display name, case-insensitively.
  name,

  /// Longest first; entries with no known duration sort last.
  duration,

  /// Largest first; entries with no known size sort last.
  size,

  /// Import order, which is the order the store holds them in.
  added,
}

/// A bin query: which folder, what the search box holds, and the order.
///
/// A value rather than widget state so the listing it produces can be tested
/// without mounting anything, and so two surfaces showing the same bin cannot
/// disagree about what "this folder, filtered" means.
@immutable
final class MediaBinQuery {
  /// Creates a query.
  const MediaBinQuery({
    this.folder,
    this.search = '',
    this.sort = MediaBinSort.added,
    this.kinds = const {},
  });

  /// The folder to show, or null for everything regardless of folder.
  ///
  /// Null is "all media", not "the root": an author searching wants to find a
  /// file they filed away, not to be told it is not in the current folder.
  final String? folder;

  /// The search text; empty matches everything.
  final String search;

  /// The listing order.
  final MediaBinSort sort;

  /// The kinds to include, or empty for all of them.
  final Set<MediaStoreKind> kinds;

  /// A copy with the named fields replaced.
  ///
  /// [folder] takes a sentinel-free path: pass `clearFolder: true` to go back
  /// to all media, since passing null cannot be told from omitting it.
  MediaBinQuery copyWith({
    String? folder,
    bool clearFolder = false,
    String? search,
    MediaBinSort? sort,
    Set<MediaStoreKind>? kinds,
  }) => MediaBinQuery(
    folder: clearFolder ? null : (folder ?? this.folder),
    search: search ?? this.search,
    sort: sort ?? this.sort,
    kinds: kinds ?? this.kinds,
  );
}

/// The entries in [entries] that [query] selects, in its order.
///
/// Pure: the bin's listing is a function of the store and the query, so a
/// panel never has to hold a filtered copy that can go stale against the
/// document.
List<MediaStoreEntry> mediaBinListing(List<MediaStoreEntry> entries, MediaBinQuery query) {
  final needle = query.search.trim().toLowerCase();
  final matched = [
    for (final entry in entries)
      if (_matches(entry, query, needle)) entry,
  ];
  return _sorted(matched, query.sort);
}

bool _matches(MediaStoreEntry entry, MediaBinQuery query, String needle) {
  if (query.folder != null && entry.folder != query.folder) return false;
  if (query.kinds.isNotEmpty && !query.kinds.contains(entry.kind)) return false;
  if (needle.isEmpty) return true;
  // The folder is searchable too: an author who remembers filing something
  // under "broll" should find it by typing that.
  return entry.name.toLowerCase().contains(needle) ||
      (entry.folder?.toLowerCase().contains(needle) ?? false);
}

List<MediaStoreEntry> _sorted(List<MediaStoreEntry> entries, MediaBinSort sort) {
  final result = [...entries];
  switch (sort) {
    case MediaBinSort.added:
      break;
    case MediaBinSort.name:
      result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case MediaBinSort.duration:
      result.sort((a, b) => _descendingNullsLast(a.durationFrames, b.durationFrames));
    case MediaBinSort.size:
      result.sort((a, b) => _descendingNullsLast(a.sizeBytes, b.sizeBytes));
  }
  return List.unmodifiable(result);
}

/// Largest first, with unknowns after everything known.
///
/// Unknowns sort last rather than as zero: a file whose duration was never
/// probed is not a short file, and sorting it among the short ones would say
/// it is.
int _descendingNullsLast(num? a, num? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}

/// Every folder any entry is filed under, sorted, without the unfiled ones.
List<String> mediaBinFolders(List<MediaStoreEntry> entries) {
  final folders = {
    for (final entry in entries)
      if (entry.folder != null) entry.folder!,
  }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return List.unmodifiable(folders);
}
