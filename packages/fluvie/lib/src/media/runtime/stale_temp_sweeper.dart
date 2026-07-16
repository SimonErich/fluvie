import 'dart:io';

/// Removes the staging directories a killed or crashed Fluvie run left behind
/// in the system temp directory.
///
/// The resolver stages a clip source, an audio source, and (streaming) every
/// extracted clip frame under `Directory.systemTemp`, and removes them in
/// `dispose`. A run that is killed, crashes, or is hot-restarted never reaches
/// `dispose`, so its directories stay — a single orphaned frame store easily
/// reaches hundreds of megabytes. This is the backstop for exactly that case;
/// `dispose` remains the primary path.
///
/// [tempDir], [maxAge], and the clock are injectable so a test can sweep a fake
/// temp directory at a fake time hermetically.
final class StaleTempSweeper {
  /// Creates a sweeper over [tempDir] (default: the system temp directory)
  /// that removes matching directories older than [maxAge], measured against
  /// [now] (default: the wall clock).
  StaleTempSweeper({Directory? tempDir, this.maxAge = defaultMaxAge, DateTime Function()? now})
    : tempDir = tempDir ?? Directory.systemTemp,
      _now = now ?? DateTime.now;

  /// The directory swept for orphans.
  final Directory tempDir;

  /// How old a directory must be before it is treated as an orphan.
  final Duration maxAge;

  final DateTime Function() _now;

  /// 24 hours.
  ///
  /// A live render must never have its staging directory deleted out from
  /// under it, and age cannot always tell a live run from a dead one: a frame
  /// store is written throughout a render and so always looks fresh, but a
  /// materialized clip or audio source is written **once** at the start of the
  /// run and never touched again. Its age therefore measures "when the run
  /// started", so the threshold has to exceed the longest plausible single
  /// render. A day is far above any real one (a very long render is hours)
  /// while still reclaiming a crashed run's disk within a day.
  static const Duration defaultMaxAge = Duration(hours: 24);

  /// The staging-directory prefixes a Fluvie run creates: the streaming clip
  /// frame store, the materialized clip source, the materialized audio source,
  /// and the per-extraction ffmpeg sandbox. `createTemp` appends random
  /// characters to each.
  ///
  /// Deliberately an explicit list rather than a `fluvie_` glob: the render
  /// pipeline's own `fluvie_frame_cache` also lives in the temp directory and
  /// is a *deliberate* cache, not an orphan. Sweeping it would delete work a
  /// re-run is meant to replay.
  static const List<String> prefixes = [
    'fluvie_clip_frames_',
    'fluvie_clip_frame_',
    'fluvie_clip_src_',
    'fluvie_audio_src_',
  ];

  /// Deletes every matching directory older than [maxAge] and returns how many
  /// were removed.
  ///
  /// Non-fatal by contract: a sweep must never fail a render, so every
  /// filesystem error (an unreadable temp directory, a directory another run
  /// removed first, one whose owner is another user) is swallowed and the sweep
  /// moves on.
  Future<int> sweep() async {
    var removed = 0;
    try {
      if (!tempDir.existsSync()) return 0;
      final cutoff = _now().subtract(maxAge);
      for (final entity in tempDir.listSync(followLinks: false)) {
        if (entity is! Directory || !_isStaging(entity)) continue;
        try {
          // Strictly older than the cutoff: a dir written exactly at it is
          // spared, so the threshold is a floor and never a rounding call.
          if (!_lastWritten(entity).isBefore(cutoff)) continue;
          entity.deleteSync(recursive: true);
          removed++;
          // coverage:ignore-start defensive arms reaching them needs a dir another user owns or a temp root that lists yet denies access neither of which a unit test can stage
        } on FileSystemException {
          // Best effort: another run's dir, or one already gone. Keep sweeping.
        }
      }
    } on FileSystemException {
      // Best effort: an unlistable temp directory is not a render failure.
    }
    // coverage:ignore-end
    return removed;
  }

  bool _isStaging(Directory dir) {
    final name = dir.path.split(Platform.pathSeparator).last;
    return prefixes.any(name.startsWith);
  }

  /// When [dir] was last written to: the newest mtime among the files below it,
  /// or the directory's own when it holds none (a run that created it and died
  /// before writing anything).
  ///
  /// Deliberately not the directory's own mtime: a frame store's files are
  /// written into per-clip subdirectories, so the store's own mtime stops
  /// moving after the first clip and a live render's store would date to its
  /// start. The files below it are what a running render keeps touching.
  DateTime _lastWritten(Directory dir) {
    DateTime? newest;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final modified = entity.statSync().modified;
      if (newest == null || modified.isAfter(newest)) newest = modified;
    }
    return newest ?? dir.statSync().modified;
  }
}
