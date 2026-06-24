import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:ai_abstracted/src/transport/retrying_http.dart';
import 'package:test/test.dart';

void main() {
  const policy = RetryPolicy(maxAttempts: 3, jitter: 0);
  final slept = <Duration>[];
  Future<void> recordSleep(Duration d) async => slept.add(d);

  setUp(slept.clear);

  group('withRetry', () {
    test('returns the first success without sleeping', () async {
      var calls = 0;
      final result = await withRetry(
        policy,
        () async {
          calls++;
          return 'ok';
        },
        sleep: recordSleep,
      );
      expect(result, 'ok');
      expect(calls, 1);
      expect(slept, isEmpty);
    });

    test('retries transient failures then succeeds', () async {
      var calls = 0;
      final result = await withRetry(
        policy,
        () async {
          calls++;
          if (calls < 3) {
            throw AiTransientException('flaky', provider: 'p');
          }
          return calls;
        },
        sleep: recordSleep,
      );
      expect(result, 3);
      expect(calls, 3);
      expect(slept, [policy.delayFor(1), policy.delayFor(2)]);
    });

    test('retries rate-limit failures by default', () async {
      var calls = 0;
      final result = await withRetry(
        policy,
        () async {
          calls++;
          if (calls < 2) {
            throw AiRateLimitException('slow', provider: 'p');
          }
          return 'done';
        },
        sleep: recordSleep,
      );
      expect(result, 'done');
      expect(calls, 2);
    });

    test('rethrows after exhausting maxAttempts', () async {
      var calls = 0;
      await expectLater(
        withRetry(
          policy,
          () async {
            calls++;
            throw AiTransientException('always', provider: 'p');
          },
          sleep: recordSleep,
        ),
        throwsA(isA<AiTransientException>()),
      );
      expect(calls, 3);
      expect(slept.length, 2);
    });

    test('does not retry a non-retryable AiException', () async {
      var calls = 0;
      await expectLater(
        withRetry(
          policy,
          () async {
            calls++;
            throw AiAuthException('no', provider: 'p');
          },
          sleep: recordSleep,
        ),
        throwsA(isA<AiAuthException>()),
      );
      expect(calls, 1);
      expect(slept, isEmpty);
    });

    test('honors a custom retryWhen predicate', () async {
      var calls = 0;
      await expectLater(
        withRetry(
          policy,
          () async {
            calls++;
            throw AiTransientException('x', provider: 'p');
          },
          retryWhen: (_) => false,
          sleep: recordSleep,
        ),
        throwsA(isA<AiTransientException>()),
      );
      expect(calls, 1);
    });
  });
}
