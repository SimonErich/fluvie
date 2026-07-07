import 'dart:convert';
import 'dart:io';

import 'package:fluvie_server/src/api/storage/download_grant.dart';
import 'package:fluvie_server/src/api/storage/file_store.dart';
import 'package:fluvie_server/src/api/storage/local_file_store.dart';
import 'package:fluvie_server/src/api/storage/stored_object.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late LocalFileStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('fluvie_server_local_');
    store = LocalFileStore(root);
    addTearDown(() => root.deleteSync(recursive: true));
  });

  Future<StoredObject> putVideo(
    String key, {
    StoreVisibility visibility = StoreVisibility.private,
    DateTime? expiresAt,
    List<int> bytes = const [1, 2, 3, 4],
  }) => store.put(
    key,
    Stream.value(bytes),
    contentType: 'video/mp4',
    visibility: visibility,
    expiresAt: expiresAt,
  );

  test('put then stat round-trips metadata and bytes', () async {
    final expiry = DateTime.utc(2026, 6, 21);
    final stored = await putVideo('rnd_1/video.mp4', expiresAt: expiry);

    expect(stored.bytes, 4);
    expect(stored.contentType, 'video/mp4');
    expect(stored.visibility, StoreVisibility.private);
    expect(stored.expiresAt, expiry);

    final read = await store.stat('rnd_1/video.mp4');
    expect(read!.bytes, 4);
    expect(read.visibility, StoreVisibility.private);
    expect(read.expiresAt, expiry);
  });

  test('put deletes the orphan .tmp when the data stream fails', () async {
    await expectLater(
      store.put(
        'rnd_9/video.mp4',
        Stream<List<int>>.error(StateError('stream boom')),
        contentType: 'video/mp4',
        visibility: StoreVisibility.private,
      ),
      throwsA(isA<StateError>()),
    );
    expect(File('${root.path}/rnd_9/video.mp4.tmp').existsSync(), isFalse);
    expect(File('${root.path}/rnd_9/video.mp4').existsSync(), isFalse);
  });

  test('put writes atomically (no leftover .tmp) and openRead streams the bytes', () async {
    await putVideo('rnd_1/video.mp4', bytes: [9, 8, 7]);
    expect(File('${root.path}/rnd_1/video.mp4.tmp').existsSync(), isFalse);

    final bytes = await store.openRead('rnd_1/video.mp4').then((s) => s.expand((c) => c).toList());
    expect(bytes, [9, 8, 7]);
  });

  test('stat returns null for an unknown key', () async {
    expect(await store.stat('missing/video.mp4'), isNull);
  });

  test('openRead throws FileStoreException for an unknown key', () async {
    expect(store.openRead('missing/video.mp4'), throwsA(isA<FileStoreException>()));
  });

  test('delete removes the file and sidecar and is idempotent', () async {
    await putVideo('rnd_1/video.mp4');
    await store.delete('rnd_1/video.mp4');
    expect(await store.stat('rnd_1/video.mp4'), isNull);
    expect(File('${root.path}/rnd_1/video.mp4.meta.json').existsSync(), isFalse);
    await store.delete('rnd_1/video.mp4'); // no throw second time
  });

  test('list yields stored objects filtered by prefix', () async {
    await putVideo('rnd_1/video.mp4');
    await putVideo('rnd_2/video.mp4');
    final all = await store.list().map((o) => o.key).toList();
    expect(all, containsAll(['rnd_1/video.mp4', 'rnd_2/video.mp4']));
    final scoped = await store.list(prefix: 'rnd_1/').map((o) => o.key).toList();
    expect(scoped, ['rnd_1/video.mp4']);
  });

  test('list skips a sidecar whose data file is gone', () async {
    await putVideo('rnd_1/video.mp4');
    File('${root.path}/rnd_1/video.mp4').deleteSync();
    expect(await store.list().toList(), isEmpty);
  });

  test('list on a never-written root is empty', () async {
    final fresh = LocalFileStore(Directory('${root.path}/nope'));
    expect(await fresh.list().toList(), isEmpty);
  });

  test('the download grant is always a stream', () async {
    await putVideo('rnd_1/video.mp4');
    final grant = await store.downloadGrant(
      'rnd_1/video.mp4',
      visibility: StoreVisibility.private,
      ttl: const Duration(minutes: 15),
    );
    expect(grant.mode, DownloadMode.stream);
  });

  test('rejects an unsafe key on every operation', () async {
    for (final key in ['../escape', '/abs', 'a//b', 'a/../b', '']) {
      expect(
        () => putVideo(key),
        throwsA(isA<FileStoreException>()),
        reason: 'put should reject "$key"',
      );
    }
    expect(store.stat('../x'), throwsA(isA<FileStoreException>()));
    expect(store.openRead('../x'), throwsA(isA<FileStoreException>()));
    expect(store.delete('../x'), throwsA(isA<FileStoreException>()));
  });

  test('the sidecar is plain JSON (no expiry key when none given)', () async {
    await putVideo('rnd_1/video.mp4');
    final meta =
        jsonDecode(File('${root.path}/rnd_1/video.mp4.meta.json').readAsStringSync())
            as Map<String, Object?>;
    expect(meta['contentType'], 'video/mp4');
    expect(meta.containsKey('expiresAtMs'), isFalse);
  });
}
