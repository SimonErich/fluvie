// The desktop clip frame store: extracted frames live on disk so a long or
// full-resolution clip never holds its whole decoded self in memory, and the
// directory goes away with the store.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/media/media_repository.dart';

Directory _tempRoot() {
  final dir = Directory.systemTemp.createTempSync('fluvie_store_test_');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

void main() {
  test('a stored frame reads back byte-identical', () async {
    final store = FileClipFrameStore(parent: _tempRoot());
    final rgba = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

    await store.put('clip-a', 3, rgba);

    expect(await store.get('clip-a', 3), rgba);
    await store.dispose();
  });

  test('frames are addressed by clip and index', () async {
    final store = FileClipFrameStore(parent: _tempRoot());

    await store.put('clip-a', 0, Uint8List.fromList([1]));
    await store.put('clip-a', 1, Uint8List.fromList([2]));
    await store.put('clip-b', 0, Uint8List.fromList([3]));

    expect(await store.get('clip-a', 0), Uint8List.fromList([1]));
    expect(await store.get('clip-a', 1), Uint8List.fromList([2]));
    expect(await store.get('clip-b', 0), Uint8List.fromList([3]));
    await store.dispose();
  });

  test('an absent frame is a miss, not an error', () async {
    final store = FileClipFrameStore(parent: _tempRoot());

    expect(await store.get('never-written', 0), isNull);

    await store.put('clip-a', 0, Uint8List.fromList([1]));
    expect(await store.get('clip-a', 99), isNull);
    await store.dispose();
  });

  test('no directory is made until a frame is put', () async {
    final root = _tempRoot();
    final store = FileClipFrameStore(parent: root);

    expect(await store.get('clip-a', 0), isNull);
    expect(store.directory, isNull, reason: 'a render with no clip makes no store dir');
    expect(root.listSync(), isEmpty);
    await store.dispose();
  });

  group('dispose', () {
    // The regression this file exists for. dispose() is reached from
    // MediaRepository.dispose(), which is a `void` and cannot await it, and a
    // render's process exits the moment it finishes. A delete left pending is
    // therefore abandoned, and the whole store (hundreds of megabytes of
    // frames) survived every single run. It must be gone before dispose returns
    // its future, not after it completes.
    test('removes the store before returning, without being awaited', () async {
      final store = FileClipFrameStore(parent: _tempRoot());
      await store.put('clip-a', 0, Uint8List.fromList([1, 2, 3, 4]));
      final dir = store.directory!;
      expect(dir.existsSync(), isTrue);

      // Deliberately not awaited: this is exactly what the caller does.
      unawaited(store.dispose());

      expect(
        dir.existsSync(),
        isFalse,
        reason: 'an unawaited dispose must still have deleted the store',
      );
    });

    test('is idempotent and safe with nothing written', () async {
      final store = FileClipFrameStore(parent: _tempRoot());

      await store.dispose();
      await store.dispose();

      expect(store.directory, isNull);
    });

    test('tolerates a store whose directory is already gone', () async {
      final store = FileClipFrameStore(parent: _tempRoot());
      await store.put('clip-a', 0, Uint8List.fromList([1]));
      store.directory!.deleteSync(recursive: true);

      await expectLater(store.dispose(), completes);
    });
  });
}
