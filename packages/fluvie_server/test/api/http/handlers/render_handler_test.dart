import 'dart:convert';

import 'package:fluvie_server/src/api/config/server_config.dart';
import 'package:fluvie_server/src/api/http/handlers/render_handler.dart';
import 'package:fluvie_server/src/api/jobs/in_memory_job_store.dart';
import 'package:fluvie_server/src/api/jobs/render_queue.dart';
import 'package:fluvie_server/src/api/storage/in_memory_file_store.dart';
import 'package:fluvie_server/src/api/storage/signed_token.dart';
import 'package:fluvie_server/src/api/validate/code_validation_result.dart';
import 'package:fluvie_server/src/api/validate/code_validation_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../../render/fakes/fake_render_runner.dart';
import '../../validate/fake_code_validation_service.dart';

const _goodCode = '''
import 'package:fluvie/fluvie.dart';
Video build() => Video(scenes: [Scene(duration: Time.seconds(1), children: const [])]);
''';

void main() {
  final now = DateTime.utc(2026, 6, 22, 10);

  late InMemoryJobStore jobs;
  late InMemoryFileStore files;
  late FakeRenderRunner runner;

  setUp(() {
    jobs = InMemoryJobStore();
    files = InMemoryFileStore(now: now);
    runner = FakeRenderRunner();
  });

  RenderHandler handler({CodeValidationService? validator}) {
    final config = serverConfigFromEnvironment({'API_TOKEN': 'api', 'CLEANUP_TOKEN': 'clean'});
    final queue = RenderQueue(
      runner: runner,
      jobStore: jobs,
      fileStore: files,
      fileTtl: config.fileTtl,
      now: () => now,
      newId: () => 'rnd_0',
    );
    return RenderHandler(
      queue: queue,
      config: config,
      signer: DownloadTokenSigner(config.downloadSigningKey),
      fileStore: files,
      codeValidator: validator ?? FakeCodeValidationService(),
    );
  }

  Request post(Object body) => Request(
    'POST',
    Uri.parse('http://localhost/v1/renders'),
    headers: const {'content-type': 'application/json'},
    body: jsonEncode(body),
  );

  Future<Map<String, Object?>> bodyOf(Response response) async =>
      jsonDecode(await response.readAsString()) as Map<String, Object?>;

  group('code render gate', () {
    test('202 and enqueues when validation is clean and imports are allowed', () async {
      final validator = FakeCodeValidationService();

      final response = await handler(validator: validator).create(post({'code': _goodCode}));

      expect(response.statusCode, 202);
      // The request trims the snippet before validating/rendering.
      expect(validator.calls.single, _goodCode.trim());
      expect(runner.calls, isEmpty, reason: 'queued; the fake runner runs async');
      // The job was created in the store.
      expect(await jobs.get('rnd_0'), isNotNull);
    });

    test('422 with the diagnostics and NO enqueue when validation fails', () async {
      final validator = FakeCodeValidationService(
        result: const CodeValidationResult([
          CodeDiagnostic(
            severity: CodeDiagnosticSeverity.error,
            message: 'Undefined name Vid.',
            line: 2,
            column: 1,
            code: 'undefined_identifier',
          ),
        ]),
      );

      final response = await handler(validator: validator).create(post({'code': 'Vid()'}));

      expect(response.statusCode, 422);
      final json = await bodyOf(response);
      expect(json['ok'], isFalse);
      final diagnostics = json['diagnostics']! as List;
      expect((diagnostics.single as Map)['code'], 'undefined_identifier');
      expect(await jobs.get('rnd_0'), isNull, reason: 'must not enqueue an invalid snippet');
    });

    test('422 and NO enqueue when an import is outside the allowlist', () async {
      final validator = FakeCodeValidationService();

      final response = await handler(validator: validator).create(
        post({'code': "import 'dart:io';\n$_goodCode"}),
      );

      expect(response.statusCode, 422);
      final json = await bodyOf(response);
      final diagnostics = json['diagnostics']! as List;
      expect(diagnostics, isNotEmpty);
      expect((diagnostics.first as Map)['message'], contains('dart:io'));
      expect(await jobs.get('rnd_0'), isNull);
    });

    test('a non-code request never calls the code validator', () async {
      final validator = FakeCodeValidationService();

      final response = await handler(validator: validator).create(post({'key': 'demo'}));

      expect(response.statusCode, 202);
      expect(validator.calls, isEmpty);
    });
  });
}
