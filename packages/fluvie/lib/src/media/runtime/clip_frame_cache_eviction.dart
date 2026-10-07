part of 'clip_frame_cache.dart';

extension _ClipCacheEviction on ClipFrameCache {
  Future<void> _sweep() async {
    try {
      if (!root.existsSync()) return;
      final entries = [
        for (final entity in root.listSync())
          if (entity is Directory) _measure(entity),
      ]..sort((a, b) => a.usedAt.compareTo(b.usedAt));
      var total = entries.fold(0, (sum, entry) => sum + entry.bytes);
      for (final entry in entries) {
        if (total <= maxBytes) return;
        entry.dir.deleteSync(recursive: true);
        total -= entry.bytes;
      }
      // coverage:ignore-start defensive arm reaching it needs a concurrent run deleting the same key or an unreadable root neither of which a unit test can stage
    } on FileSystemException {
      // Best effort: an unsweepable cache is over budget, not broken.
    }
    // coverage:ignore-end
  }

  /// One clip key's total bytes and newest mtime (its LRU recency).
  _CacheEntry _measure(Directory dir) {
    var bytes = 0;
    var usedAt = DateTime.fromMillisecondsSinceEpoch(0);
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final stat = entity.statSync();
      bytes += stat.size;
      if (stat.modified.isAfter(usedAt)) usedAt = stat.modified;
    }
    return _CacheEntry(dir, bytes, usedAt);
  }
}

/// One measured clip key directory: how much it holds and when it was last used.
final class _CacheEntry {
  const _CacheEntry(this.dir, this.bytes, this.usedAt);

  final Directory dir;
  final int bytes;
  final DateTime usedAt;
}
