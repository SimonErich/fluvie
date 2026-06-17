import 'package:fluvie_api/src/storage/download_grant.dart';
import 'package:fluvie_api/src/storage/file_store.dart';
import 'package:fluvie_api/src/storage/s3_file_store.dart';
import 'package:fluvie_api/src/storage/s3_object_storage.dart';
import 'package:fluvie_api/src/storage/stored_object.dart';
import 'package:test/test.dart';

import 'fakes/fake_s3_object_storage.dart';

/// An S3 backend whose uploads silently vanish, to exercise the persist check.
final class _DroppingStorage implements S3ObjectStorage {
  @override
  Future<void> putObject(
    String key,
    Stream<List<int>> data, {
    required int length,
    required Map<String, String> metadata,
  }) async {}

  @override
  Future<S3ObjectStat?> statObject(String key) async => null;

  @override
  Future<Stream<List<int>>> getObject(String key) async => const Stream.empty();

  @override
  Future<void> removeObject(String key) async {}

  @override
  Stream<S3ObjectEntry> listObjects({String? prefix}) => const Stream.empty();

  @override
  Future<Uri> presignedGetUrl(String key, {required Duration expires}) async => Uri();
}

void main() {
  late FakeS3ObjectStorage backend;
  late S3FileStore store;

  setUp(() {
    backend = FakeS3ObjectStorage(now: DateTime.utc(2026, 6, 20));
    store = S3FileStore(backend);
  });

  Future<StoredObject> put(
    String key, {
    StoreVisibility visibility = StoreVisibility.private,
    DateTime? expiresAt,
  }) => store.put(
    key,
    Stream.value(const [1, 2, 3, 4, 5]),
    contentType: 'video/mp4',
    visibility: visibility,
    length: 5,
    expiresAt: expiresAt,
  );

  test('put stores bytes + metadata and stat maps them back', () async {
    final expiry = DateTime.utc(2026, 6, 22);
    final stored = await put('rnd_1/video.mp4', expiresAt: expiry);
    expect(stored.bytes, 5);
    expect(stored.contentType, 'video/mp4');
    expect(stored.visibility, StoreVisibility.private);
    expect(stored.expiresAt, expiry);
    expect(stored.createdAt, DateTime.utc(2026, 6, 20));

    final read = await store.stat('rnd_1/video.mp4');
    expect(read!.expiresAt, expiry);
    expect(read.visibility, StoreVisibility.private);
  });

  test('put without a length is rejected (S3 needs the size up front)', () {
    expect(
      () => store.put(
        'rnd_1/video.mp4',
        Stream.value(const [1]),
        contentType: 'video/mp4',
        visibility: StoreVisibility.public,
      ),
      throwsA(isA<FileStoreException>()),
    );
  });

  test('put rejects an unsafe key', () {
    expect(() => put('../escape'), throwsA(isA<FileStoreException>()));
  });

  test('put throws when the upload does not persist', () {
    final dropping = S3FileStore(_DroppingStorage());
    expect(
      () => dropping.put(
        'rnd_1/video.mp4',
        Stream.value(const [1]),
        contentType: 'video/mp4',
        visibility: StoreVisibility.private,
        length: 1,
      ),
      throwsA(isA<FileStoreException>().having((e) => e.message, 'm', contains('persist'))),
    );
  });

  test('stat returns null and openRead throws for an unknown key', () async {
    expect(await store.stat('missing/video.mp4'), isNull);
    expect(store.openRead('missing/video.mp4'), throwsA(isA<FileStoreException>()));
  });

  test('openRead streams the stored bytes', () async {
    await put('rnd_1/video.mp4');
    expect(
      await store.openRead('rnd_1/video.mp4').then((s) => s.expand((c) => c).toList()),
      [1, 2, 3, 4, 5],
    );
  });

  test('delete removes the object (idempotent)', () async {
    await put('rnd_1/video.mp4');
    await store.delete('rnd_1/video.mp4');
    expect(backend.keys, isEmpty);
    await store.delete('rnd_1/video.mp4');
  });

  test('list stats each entry and filters by prefix', () async {
    await put('rnd_1/video.mp4');
    await put('rnd_2/video.mp4');
    final keys = await store.list(prefix: 'rnd_1/').map((o) => o.key).toList();
    expect(keys, ['rnd_1/video.mp4']);
    expect(await store.list().length, 2);
  });

  test('public download grant redirects to the public base URL when set', () async {
    final cdnStore = S3FileStore(backend, publicBaseUrl: Uri.parse('https://cdn.test/bucket/'));
    await cdnStore.put(
      'rnd_1/video.mp4',
      Stream.value(const [1]),
      contentType: 'video/mp4',
      visibility: StoreVisibility.public,
      length: 1,
    );
    final grant = await cdnStore.downloadGrant(
      'rnd_1/video.mp4',
      visibility: StoreVisibility.public,
      ttl: const Duration(minutes: 15),
    );
    expect(grant.mode, DownloadMode.redirect);
    expect(grant.url, Uri.parse('https://cdn.test/bucket/rnd_1/video.mp4'));
  });

  test('public download grant streams through when no public base URL', () async {
    await put('rnd_1/video.mp4', visibility: StoreVisibility.public);
    final grant = await store.downloadGrant(
      'rnd_1/video.mp4',
      visibility: StoreVisibility.public,
      ttl: const Duration(minutes: 15),
    );
    expect(grant.mode, DownloadMode.stream);
  });

  test('private download grant redirects to a presigned URL carrying the TTL', () async {
    await put('rnd_1/video.mp4');
    final grant = await store.downloadGrant(
      'rnd_1/video.mp4',
      visibility: StoreVisibility.private,
      ttl: const Duration(minutes: 15),
    );
    expect(grant.mode, DownloadMode.redirect);
    expect(grant.url, Uri.parse('https://s3.test/rnd_1/video.mp4?expires=900'));
  });
}
