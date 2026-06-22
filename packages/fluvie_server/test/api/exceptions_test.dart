import 'package:fluvie_server/src/api/client/api_client_exception.dart';
import 'package:fluvie_server/src/api/config/server_config.dart';
import 'package:fluvie_server/src/api/http/api_error.dart';
import 'package:fluvie_server/src/api/render/render_request.dart';
import 'package:fluvie_server/src/api/render/render_runner.dart';
import 'package:fluvie_server/src/api/storage/file_store.dart';
import 'package:test/test.dart';

void main() {
  test('exception toString methods are descriptive', () {
    expect(const ServerConfigException('bad').toString(), contains('bad'));
    expect(const RenderRequestException('nope').toString(), contains('nope'));
    expect(const RenderFailure('boom').toString(), contains('boom'));
    expect(const FileStoreException('gone').toString(), contains('gone'));
    expect(const ApiError.badRequest('x').toString(), contains('400'));
    expect(
      const ApiClientException('oops').toString(),
      'ApiClientException: oops',
    );
    expect(
      const ApiClientException('oops', statusCode: 500).toString(),
      'ApiClientException(500): oops',
    );
  });
}
