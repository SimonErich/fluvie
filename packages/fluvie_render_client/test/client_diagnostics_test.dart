import 'package:fluvie_render_client/fluvie_render_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('validation retains unknown severity as informational and default locations', () {
    final result = ApiValidationResult.fromJson(const {
      'diagnostics': [
        {'severity': 'future-note'},
      ],
    });
    expect(result.ok, isFalse);
    expect(result.diagnostics.single.severity, ApiDiagnosticSeverity.info);
    expect(result.diagnostics.single.message, isEmpty);
    expect(result.diagnostics.single.line, 1);
    expect(result.diagnostics.single.column, 1);
    expect(result.diagnostics.single.length, isNull);
    expect(ApiValidationResult.fromJson(const {}).diagnostics, isEmpty);
  });

  test('malformed validation replies are actionable API errors', () async {
    final client = ApiRenderClient(
      baseUrl: Uri.parse('https://render.test/'),
      httpClient: MockClient((_) async => http.Response('[]', 200)),
    );
    addTearDown(client.close);
    await expectLater(
      client.validate('Video build() => Video(scenes: const []);'),
      throwsA(
        isA<ApiClientException>().having(
          (error) => error.message,
          'message',
          'Malformed response from the validate API',
        ),
      ),
    );
  });

  test('diagnostic strings preserve HTTP context when available', () {
    expect(const ApiClientException('offline').toString(), 'ApiClientException: offline');
    expect(
      const ApiClientException('denied', statusCode: 401).toString(),
      'ApiClientException(401): denied',
    );
  });

  test('job fractions remain bounded and artifact expiry preserves UTC', () {
    expect(const RenderJobView(id: 'a', status: 'running', completed: 6, total: 5).progress, 1);
    expect(const RenderJobView(id: 'a', status: 'running', completed: -1, total: 5).progress, 0);
    expect(const RenderJobView(id: 'a', status: 'queued', completed: 0, total: 0).progress, 0);
    final link = FileLink.fromJson(const {
      'downloadUrl': 'https://render.test/video?token=signed',
      'expiresAt': '2026-10-05T12:00:00+02:00',
    });
    expect(link.expiresAt, DateTime.utc(2026, 10, 5, 10));
    expect(link.toJson()['expiresAt'], '2026-10-05T10:00:00.000Z');
  });

  test('partial job progress is unknown rather than an exception', () {
    final view = RenderJobView.fromJson(const {
      'id': 'a',
      'status': 'running',
      'progress': {'total': 120},
    });
    expect(view.completed, isNull);
    expect(view.progress, 0);
  });
}
