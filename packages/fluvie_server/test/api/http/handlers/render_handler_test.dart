import 'dart:convert';

import 'package:fluvie_server/src/api/config/server_config.dart';
import 'package:fluvie_server/src/api/http/api_error.dart';
import 'package:fluvie_server/src/api/http/handlers/render_handler.dart';
import 'package:fluvie_server/src/api/jobs/in_memory_job_store.dart';
import 'package:fluvie_server/src/api/jobs/render_queue.dart';
import 'package:fluvie_server/src/api/ratelimit/rate_limiter.dart';
import 'package:fluvie_server/src/api/storage/in_memory_file_store.dart';
import 'package:fluvie_server/src/api/storage/signed_token.dart';
import 'package:fluvie_server/src/api/validate/code_validation_result.dart';
import 'package:fluvie_server/src/api/validate/code_validation_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../../ratelimit/fakes/fake_rate_limiter.dart';
import '../../render/fakes/fake_render_runner.dart';
import '../../validate/fakes/fake_code_validation_service.dart';

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

  RenderHandler handler({
    CodeValidationService? validator,
    RateLimiter? rateLimiter,
    Map<String, String> env = const {},
  }) {
    final config = serverConfigFromEnvironment({
      'API_TOKEN': 'api',
      'CLEANUP_TOKEN': 'clean',
      ...env,
    });
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
      rateLimiter: rateLimiter ?? FakeRateLimiter(),
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

  group('AI rate limiting', () {
    Request postFrom(String ip, Object body) => Request(
      'POST',
      Uri.parse('http://localhost/v1/renders'),
      headers: {'content-type': 'application/json', 'x-forwarded-for': ip},
      body: jsonEncode(body),
    );

    test('429 with Retry-After and a JSON body when a prompt render is over quota', () async {
      final limiter = FakeRateLimiter(
        decision: const RateLimitDecision.deny(Duration(seconds: 42)),
      );

      final response = await handler(
        rateLimiter: limiter,
        env: const {'ANTHROPIC_API_KEY': 'sk'},
      ).create(postFrom('203.0.113.5', {'prompt': 'a promo'}));

      expect(response.statusCode, 429);
      expect(response.headers['retry-after'], '42');
      final json = await bodyOf(response);
      final error = json['error']! as Map<String, Object?>;
      expect(error['code'], 'rate_limited');
      expect(error['retryAfterSeconds'], 42);
      expect(limiter.calls.single, '203.0.113.5');
      expect(await jobs.get('rnd_0'), isNull, reason: 'a throttled request is never enqueued');
    });

    test('an edit render is also rate limited', () async {
      final limiter = FakeRateLimiter(
        decision: const RateLimitDecision.deny(Duration(seconds: 10)),
      );

      final response =
          await handler(
            rateLimiter: limiter,
            env: const {'ANTHROPIC_API_KEY': 'sk'},
          ).create(
            postFrom('1.2.3.4', {
              'edit': {
                'base': {
                  'scenes': [
                    {'duration': '1s'},
                  ],
                },
                'change': 'bluer',
              },
            }),
          );

      expect(response.statusCode, 429);
      expect(limiter.calls.single, '1.2.3.4');
    });

    test('a code render is never rate limited', () async {
      final limiter = FakeRateLimiter(
        decision: const RateLimitDecision.deny(Duration(seconds: 99)),
      );

      final response = await handler(rateLimiter: limiter).create(post({'code': _goodCode}));

      expect(response.statusCode, 202);
      expect(limiter.calls, isEmpty, reason: 'code renders carry no LLM cost');
    });

    test('a key/spec render is never rate limited', () async {
      final limiter = FakeRateLimiter(
        decision: const RateLimitDecision.deny(Duration(seconds: 99)),
      );

      final response = await handler(rateLimiter: limiter).create(post({'key': 'demo'}));

      expect(response.statusCode, 202);
      expect(limiter.calls, isEmpty);
    });

    test('503 wins over rate limiting when AI is unconfigured', () async {
      final limiter = FakeRateLimiter(
        decision: const RateLimitDecision.deny(Duration(seconds: 5)),
      );

      // The 503 surfaces as an ApiError (the error middleware maps it); the key
      // guarantee is the limiter is never consulted for an unconfigured server.
      await expectLater(
        handler(rateLimiter: limiter).create(post({'prompt': 'a promo'})),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'statusCode', 503)),
      );
      expect(limiter.calls, isEmpty, reason: 'no LLM cost to guard when unconfigured');
    });

    test('a permitted prompt render proceeds and consumes budget', () async {
      final limiter = FakeRateLimiter();

      final response = await handler(
        rateLimiter: limiter,
        env: const {'ANTHROPIC_API_KEY': 'sk'},
      ).create(postFrom('9.9.9.9', {'prompt': 'a promo'}));

      expect(response.statusCode, 202);
      expect(limiter.calls.single, '9.9.9.9');
    });
  });
}
