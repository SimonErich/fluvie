import 'package:fluvie_server/src/api/storage/download_grant.dart';
import 'package:fluvie_server/src/api/storage/file_store.dart';
import 'package:fluvie_server/src/api/storage/in_memory_file_store.dart';
import 'package:fluvie_server/src/api/storage/stored_object.dart';
import 'package:test/test.dart';

void main() {
  late InMemoryFileStore store;

  setUp(() => store = InMemoryFileStore(now: DateTime.utc(2026, 6, 20)));

  Future<StoredObject> put(String key, {DateTime? expiresAt}) => store.put(
    key,
    Stream.value(const [1, 2, 3]),
    contentType: 'video/mp4',
    visibility: StoreVisibility.public,
    expiresAt: expiresAt,
  );

  test('put/stat/openRead round-trip with the injected createdAt', () async {
    final stored = await put('rnd_1/video.mp4');
    expect(stored.createdAt, DateTime.utc(2026, 6, 20));
    expect((await store.stat('rnd_1/video.mp4'))!.bytes, 3);
    expect(
      await store.openRead('rnd_1/video.mp4').then((s) => s.expand((c) => c).toList()),
      [1, 2, 3],
    );
  });

  test('openRead throws for an unknown key; stat returns null', () async {
    expect(await store.stat('x/y.mp4'), isNull);
    expect(store.openRead('x/y.mp4'), throwsA(isA<FileStoreException>()));
  });

  test('delete is idempotent and list filters by prefix', () async {
    await put('a/video.mp4');
    await put('b/video.mp4');
    await store.delete('a/video.mp4');
    await store.delete('a/video.mp4');
    expect(await store.list().map((o) => o.key).toList(), ['b/video.mp4']);
    expect(await store.list(prefix: 'b/').map((o) => o.key).toList(), ['b/video.mp4']);
  });

  test('rejects an unsafe key', () {
    expect(() => put('../escape'), throwsA(isA<FileStoreException>()));
  });

  test('the download grant is always a stream', () async {
    await put('a/video.mp4');
    final grant = await store.downloadGrant(
      'a/video.mp4',
      visibility: StoreVisibility.public,
      ttl: const Duration(minutes: 1),
    );
    expect(grant.mode, DownloadMode.stream);
  });
}
