import 'package:fluvie_server/src/api/config/server_config.dart';
import 'package:fluvie_server/src/api/jobs/file_job_store.dart';
import 'package:fluvie_server/src/api/server_factory.dart';
import 'package:fluvie_server/src/api/storage/local_file_store.dart';
import 'package:fluvie_server/src/api/storage/s3_file_store.dart';
import 'package:test/test.dart';

void main() {
  group('buildServerDependencies', () {
    test('wires a LocalFileStore for the local backend', () {
      final config = serverConfigFromEnvironment({
        'API_TOKEN': 'a',
        'CLEANUP_TOKEN': 'c',
        'LOCAL_STORAGE_DIR': '/tmp/fluvie-test',
      });
      final deps = buildServerDependencies(config, schemaJson: '{"x":1}');
      expect(deps.fileStore, isA<LocalFileStore>());
      expect(deps.jobStore, isA<FileJobStore>());
      expect(deps.schemaJson, '{"x":1}');
      expect(deps.config, same(config));
    });

    test('wires an S3FileStore for the s3 backend (no network on construction)', () {
      final config = serverConfigFromEnvironment({
        'API_TOKEN': 'a',
        'CLEANUP_TOKEN': 'c',
        'STORAGE_BACKEND': 's3',
        'S3_ENDPOINT': 's3.example.com',
        'S3_BUCKET': 'renders',
        'S3_ACCESS_KEY': 'ak',
        'S3_SECRET_KEY': 'sk',
      });
      final deps = buildServerDependencies(config);
      expect(deps.fileStore, isA<S3FileStore>());
    });
  });

  test('jobStoreFor points at the storage dir jobs folder', () {
    final config = serverConfigFromEnvironment({
      'API_TOKEN': 'a',
      'CLEANUP_TOKEN': 'c',
      'LOCAL_STORAGE_DIR': '/tmp/fluvie-test',
    });
    expect(jobStoreFor(config).dir.path, '/tmp/fluvie-test/.jobs');
  });
}
