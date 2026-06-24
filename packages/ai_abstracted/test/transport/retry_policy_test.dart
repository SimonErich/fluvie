import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:test/test.dart';

void main() {
  group('RetryPolicy', () {
    test('exposes the documented defaults', () {
      const policy = RetryPolicy();
      expect(policy.maxAttempts, 4);
      expect(policy.baseDelay, const Duration(milliseconds: 400));
      expect(policy.maxDelay, const Duration(seconds: 8));
      expect(policy.jitter, 0.2);
    });

    test('delayFor grows exponentially from the base delay', () {
      const policy = RetryPolicy(jitter: 0);
      expect(policy.delayFor(1), const Duration(milliseconds: 400));
      expect(policy.delayFor(2), const Duration(milliseconds: 800));
      expect(policy.delayFor(3), const Duration(milliseconds: 1600));
    });

    test('delayFor never exceeds maxDelay', () {
      const policy = RetryPolicy(jitter: 0);
      expect(policy.delayFor(99), const Duration(seconds: 8));
    });

    test('delayFor stays within the jitter band around the base curve', () {
      const policy = RetryPolicy();
      const expectedMs = 400;
      for (var i = 0; i < 50; i++) {
        final ms = policy.delayFor(1).inMilliseconds;
        expect(ms, greaterThanOrEqualTo((expectedMs * 0.8).floor()));
        expect(ms, lessThanOrEqualTo((expectedMs * 1.2).ceil()));
      }
    });

    test('delayFor clamps non-positive attempts to the first step', () {
      const policy = RetryPolicy(jitter: 0);
      expect(policy.delayFor(0), const Duration(milliseconds: 400));
      expect(policy.delayFor(-5), const Duration(milliseconds: 400));
    });
  });

  group('retryableStatus', () {
    test('true for 429 and 5xx', () {
      expect(retryableStatus(429), isTrue);
      expect(retryableStatus(500), isTrue);
      expect(retryableStatus(503), isTrue);
    });

    test('false for other statuses', () {
      expect(retryableStatus(200), isFalse);
      expect(retryableStatus(400), isFalse);
      expect(retryableStatus(401), isFalse);
      expect(retryableStatus(404), isFalse);
    });
  });
}
