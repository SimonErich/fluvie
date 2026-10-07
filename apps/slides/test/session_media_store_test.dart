import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart'
    show AudioSource, BundleMedia, FileSource, MediaSource, MemorySource;
import 'package:slides/editor/session_media_io.dart';
import 'package:slides/editor/session_media_store.dart';

Uint8List _bytes(List<int> data) => Uint8List.fromList(data);

void main() {
  tearDown(() => BundleMedia.current = null);

  SessionMediaStore store({int budget = 1 << 20}) =>
      SessionMediaStore(budgetBytes: budget, materialize: memorySessionMaterializer);

  group('register', () {
    test('stores the bytes under media/<name> and publishes the bundle scope', () async {
      final session = store();
      final value = await session.register('photo.png', _bytes([1, 2, 3]));
      expect(value, 'media/photo.png');
      expect(session.bytesFor(value), _bytes([1, 2, 3]));
      expect(BundleMedia.current!.media['media/photo.png'], isA<MemorySource>());
    });

    test('sanitizes a dropped path down to its file name', () async {
      final session = store();
      expect(await session.register('/home/ada/b roll.mp4', _bytes([1])), 'media/b roll.mp4');
      expect(await session.register(r'C:\clips\intro.mp4', _bytes([2])), 'media/intro.mp4');
    });

    test('the same file registers once; a name clash gets a numbered value', () async {
      final session = store();
      final first = await session.register('photo.png', _bytes([1, 2, 3]));
      final again = await session.register('photo.png', _bytes([1, 2, 3]));
      expect(again, first);
      final clash = await session.register('photo.png', _bytes([9, 9]));
      expect(clash, 'media/photo-2.png');
      expect(session.bytesFor(clash), _bytes([9, 9]));
    });

    test('audio lands in the audio map, visuals in the media map', () async {
      final session = store();
      await session.register('bed.mp3', _bytes([1]));
      await session.register('photo.png', _bytes([2]));
      final bundle = session.bundleMedia();
      expect(bundle.audio.keys, ['media/bed.mp3']);
      expect(bundle.media.keys, ['media/photo.png']);
    });

    test('a register past the byte budget refuses with a visible error', () async {
      final session = store(budget: 4);
      await session.register('a.png', _bytes([1, 2]));
      expect(
        () => session.register('b.png', _bytes([1, 2, 3])),
        throwsA(isA<SessionMediaBudgetError>()),
      );
      expect(session.heldBytes, 2);
    });
  });

  group('adopt and clear', () {
    test('adopt takes an unpacked bundle verbatim and publishes it', () async {
      final session = store();
      await session.adopt({
        'media/b-roll.mp4': _bytes([5, 6]),
      });
      expect(session.bytesFor('media/b-roll.mp4'), _bytes([5, 6]));
      expect(BundleMedia.current!.media.keys, ['media/b-roll.mp4']);
    });

    test('adopting an identical held entry is free (a recovery over a reopened bundle)', () async {
      final session = store(budget: 4);
      await session.adopt({
        'media/a.png': _bytes([1, 2, 3]),
      });
      // The sidecar's copy of the same media must never trip the budget.
      await session.adopt({
        'media/a.png': _bytes([1, 2, 3]),
      });
      expect(session.heldBytes, 3);
      expect(session.bytesFor('media/a.png'), _bytes([1, 2, 3]));
    });

    test('adopt replacing an entry counts only the delta against the budget', () async {
      final session = store(budget: 4);
      await session.adopt({
        'media/a.png': _bytes([1, 2, 3]),
      });
      await session.adopt({
        'media/a.png': _bytes([9, 9, 9, 9]),
      });
      expect(session.heldBytes, 4);
      expect(session.bytesFor('media/a.png'), _bytes([9, 9, 9, 9]));
    });

    test('clear empties the store and retires the published scope', () async {
      final session = store();
      await session.register('photo.png', _bytes([1]));
      session.clear();
      expect(session.heldBytes, 0);
      expect(session.bytes, isEmpty);
      expect(BundleMedia.current, isNull);
    });
  });

  group('memorySessionMaterializer', () {
    test('wraps the bytes as memory sources named by their value', () async {
      final sources = await memorySessionMaterializer('media/photo.png', _bytes([1]));
      expect(
        sources.media,
        isA<MemorySource>().having((s) => s.debugLabel, 'debugLabel', 'media/photo.png'),
      );
      expect(sources.media, isA<MediaSource>());
    });
  });

  group('sessionMaterializerFor (desktop)', () {
    test('writes the bytes under one sandboxed directory as honest file sources', () async {
      final temp = await Directory.systemTemp.createTemp('fluvie_session_test_');
      addTearDown(() => temp.delete(recursive: true));
      final materialize = sessionMaterializerFor(directory: temp.path);
      final sources = await materialize('media/photo.png', _bytes([7, 8]));
      final path = (sources.media as FileSource).path;
      expect(path, startsWith(temp.path));
      expect(await File(path).readAsBytes(), _bytes([7, 8]));
      expect(sources.audio, isA<AudioSource>());
    });
  });
}
