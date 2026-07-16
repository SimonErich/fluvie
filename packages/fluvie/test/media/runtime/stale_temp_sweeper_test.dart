// The orphan sweep: a run that is killed or crashes never reaches dispose, so
// its staging directories stay in the system temp directory (an orphaned clip
// frame store reaches hundreds of megabytes). These sweep a fake temp directory
// at a fake clock, so nothing here touches the real one.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/media/runtime/stale_temp_sweeper.dart';

void main() {
  late Directory temp;
  final now = DateTime(2026, 7, 15, 12);

  setUp(() {
    temp = Directory.systemTemp.createTempSync('fluvie_sweeper_test_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
  });

  StaleTempSweeper sweeper({Duration maxAge = StaleTempSweeper.defaultMaxAge}) =>
      StaleTempSweeper(tempDir: temp, maxAge: maxAge, now: () => now);

  /// A staging dir holding one frame file, last written [age] ago — the shape
  /// a run leaves behind. The sweep dates a dir by the files below it, so the
  /// payload's mtime is what ages it.
  Directory staged(String name, {required Duration age}) {
    final dir = Directory('${temp.path}/$name/clipkey')..createSync(recursive: true);
    File('${dir.path}/0.rgba')
      ..writeAsBytesSync(const [1, 2, 3])
      ..setLastModifiedSync(now.subtract(age));
    return dir.parent;
  }

  test('an old clip frame store is removed', () async {
    final orphan = staged('fluvie_clip_frames_PQUZKG', age: const Duration(days: 3));

    expect(await sweeper().sweep(), 1);

    expect(orphan.existsSync(), isFalse);
  });

  // The threshold must clear the longest plausible render: a staging dir's
  // mtime is set when the run creates it and never refreshed, so a fresh dir
  // may well belong to a render that is still running.
  test('a fresh clip frame store is spared', () async {
    final live = staged('fluvie_clip_frames_LIVE01', age: const Duration(hours: 1));

    expect(await sweeper().sweep(), 0);

    expect(live.existsSync(), isTrue);
  });

  // A store holds many frames written over the whole render, so the newest of
  // them is what dates it: one stale frame among fresh ones is a live run.
  test('a store is dated by its newest frame, not its oldest', () async {
    final live = staged('fluvie_clip_frames_LIVE02', age: const Duration(days: 3));
    File('${live.path}/clipkey/1.rgba')
      ..writeAsBytesSync(const [1, 2, 3])
      ..setLastModifiedSync(now.subtract(const Duration(minutes: 5)));

    expect(await sweeper().sweep(), 0);

    expect(live.existsSync(), isTrue, reason: 'a render still writing frames is not an orphan');
  });

  test('a dir at exactly the age threshold is spared', () async {
    final edge = staged('fluvie_clip_frames_EDGE01', age: StaleTempSweeper.defaultMaxAge);

    await sweeper().sweep();

    expect(edge.existsSync(), isTrue, reason: 'only strictly older dirs are orphans');
  });

  test('an old materialized clip source is removed', () async {
    final orphan = staged('fluvie_clip_src_ABC123', age: const Duration(days: 2));

    expect(await sweeper().sweep(), 1);

    expect(orphan.existsSync(), isFalse);
  });

  test('an old materialized audio source is removed', () async {
    final orphan = staged('fluvie_audio_src_ABC123', age: const Duration(days: 2));

    expect(await sweeper().sweep(), 1);

    expect(orphan.existsSync(), isFalse);
  });

  test('every staging prefix is swept in one pass', () async {
    for (final prefix in StaleTempSweeper.prefixes) {
      staged('${prefix}OLD001', age: const Duration(days: 2));
    }

    expect(await sweeper().sweep(), StaleTempSweeper.prefixes.length);
  });

  // The ffmpeg extraction sandbox is removed in a finally, so only a killed
  // run leaves one; it is the same class of orphan.
  test('an old ffmpeg extraction sandbox is removed', () async {
    final orphan = staged('fluvie_clip_frame_XYZ789', age: const Duration(days: 2));

    expect(await sweeper().sweep(), 1);

    expect(orphan.existsSync(), isFalse);
  });

  test('an unrelated old temp dir is left alone', () async {
    final other = staged('some_other_tool_cache', age: const Duration(days: 30));

    expect(await sweeper().sweep(), 0);

    expect(other.existsSync(), isTrue);
  });

  // The render pipeline's frame cache lives in the temp dir too and is a
  // deliberate cache, not an orphan: replaying it is the whole point.
  test('the render pipeline frame cache is never swept', () async {
    final cache = staged('fluvie_frame_cache', age: const Duration(days: 30));

    expect(await sweeper().sweep(), 0);

    expect(cache.existsSync(), isTrue);
  });

  test('an old file that merely looks like a staging dir is left alone', () async {
    final file = File('${temp.path}/fluvie_clip_src_notadir')
      ..writeAsBytesSync(const [1])
      ..setLastModifiedSync(now.subtract(const Duration(days: 30)));

    expect(await sweeper().sweep(), 0);

    expect(file.existsSync(), isTrue);
  });

  test('the sweep spares the fresh and removes the old in one pass', () async {
    final orphan = staged('fluvie_clip_frames_OLD001', age: const Duration(days: 2));
    final live = staged('fluvie_clip_frames_NEW001', age: const Duration(minutes: 5));

    expect(await sweeper().sweep(), 1);

    expect(orphan.existsSync(), isFalse);
    expect(live.existsSync(), isTrue);
  });

  test('a shorter maxAge widens what counts as an orphan', () async {
    final dir = staged('fluvie_clip_frames_OLD002', age: const Duration(hours: 2));

    expect(await sweeper(maxAge: const Duration(hours: 1)).sweep(), 1);

    expect(dir.existsSync(), isFalse);
  });

  // A run can create its staging dir and die before writing into it, leaving
  // nothing to date it by. The dir's own mtime is the fallback, so a dir just
  // created by a live run is still spared.
  test('an empty staging dir falls back to its own mtime and is spared', () async {
    final empty = Directory('${temp.path}/fluvie_clip_frames_EMPTY1')..createSync();

    expect(await sweeper().sweep(), 0);

    expect(empty.existsSync(), isTrue);
  });

  test('a missing temp dir sweeps nothing rather than throwing', () async {
    temp.deleteSync(recursive: true);

    expect(await sweeper().sweep(), 0);
  });

  test('the default threshold clears the longest plausible render', () {
    expect(StaleTempSweeper.defaultMaxAge, const Duration(hours: 24));
  });

  test('the default sweeper targets the real system temp dir', () {
    expect(StaleTempSweeper().tempDir.path, Directory.systemTemp.path);
  });
}
