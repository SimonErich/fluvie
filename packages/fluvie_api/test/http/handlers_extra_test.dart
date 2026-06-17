import 'package:fluvie_api/src/config/server_config.dart';
import 'package:fluvie_api/src/http/handlers/download_handler.dart';
import 'package:fluvie_api/src/http/handlers/health_handler.dart';
import 'package:fluvie_api/src/jobs/in_memory_job_store.dart';
import 'package:fluvie_api/src/jobs/job_status.dart';
import 'package:fluvie_api/src/jobs/render_job.dart';
import 'package:fluvie_api/src/storage/download_grant.dart';
import 'package:fluvie_api/src/storage/file_store.dart';
import 'package:fluvie_api/src/storage/signed_token.dart';
import 'package:fluvie_api/src/storage/stored_object.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// A FileStore whose stat/grant behavior is configurable for branch tests.
final class _FakeFileStore implements FileStore {
  _FakeFileStore({this.statThrows = false, this.grant = const DownloadGrant.stream()});
  final bool statThrows;
  final DownloadGrant grant;

  @override
  Future<StoredObject?> stat(String key) async {
    if (statThrows) throw const FileStoreException('down');
    return StoredObject(
      key: key,
      bytes: 4,
      contentType: 'video/mp4',
      createdAt: DateTime.utc(2026),
      visibility: StoreVisibility.public,
    );
  }

  @override
  Future<DownloadGrant> downloadGrant(
    String key, {
    required StoreVisibility visibility,
    required Duration ttl,
  }) async => grant;

  @override
  Future<Stream<List<int>>> openRead(String key) async => Stream.value(const [1]);

  @override
  Future<void> delete(String key) async {}

  @override
  Stream<StoredObject> list({String? prefix}) => const Stream.empty();

  @override
  Future<StoredObject> put(
    String key,
    Stream<List<int>> data, {
    required String contentType,
    required StoreVisibility visibility,
    int? length,
    DateTime? expiresAt,
  }) async => throw UnimplementedError();
}

ServerConfig _config() =>
    serverConfigFromEnvironment(const {'API_TOKEN': 'api', 'CLEANUP_TOKEN': 'clean'});

void main() {
  test('readyz reports degraded when the file store is unreachable', () async {
    final handler = HealthHandler(_FakeFileStore(statThrows: true));
    final response = await handler.ready(Request('GET', Uri.parse('http://x/v1/readyz')));
    expect(response.statusCode, 503);
  });

  test('the download handler 302-redirects when the store returns a redirect grant', () async {
    final jobs = InMemoryJobStore();
    await jobs.create(
      RenderJob(
        id: 'rnd_1',
        kind: RenderJobKind.key,
        status: JobStatus.succeeded,
        visibility: StoreVisibility.public,
        createdAt: DateTime.utc(2026),
        expiresAt: DateTime.utc(2027),
        videoKey: 'rnd_1/video.mp4',
      ),
    );
    final handler = DownloadHandler(
      jobStore: jobs,
      fileStore: _FakeFileStore(grant: DownloadGrant.redirect(Uri.parse('https://cdn/v.mp4'))),
      config: _config(),
      signer: DownloadTokenSigner(_config().downloadSigningKey),
    );

    final response = await handler.get(
      Request('GET', Uri.parse('http://x/v1/files/rnd_1/video')),
      'rnd_1',
      'video',
    );
    expect(response.statusCode, 302);
    expect(response.headers['location'], 'https://cdn/v.mp4');
  });
}
