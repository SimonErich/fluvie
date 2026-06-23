import 'package:fluvie_server/src/api/ratelimit/in_memory_rate_limiter.dart';
import 'package:fluvie_server/src/api/ratelimit/rate_limiter.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryRateLimiter', () {
    test('allows up to the window limit, then rejects with a retry hint', () async {
      final now = DateTime.utc(2026, 6, 23, 12);
      final limiter = InMemoryRateLimiter(
        limit: 2,
        window: const Duration(seconds: 60),
        dailyQuota: 100,
        now: () => now,
      );

      expect((await limiter.check('1.1.1.1')).allowed, isTrue);
      expect((await limiter.check('1.1.1.1')).allowed, isTrue);
      final third = await limiter.check('1.1.1.1');
      expect(third.allowed, isFalse);
      // The retry hint is the seconds until the oldest hit leaves the window.
      expect(third.retryAfter, const Duration(seconds: 60));
    });

    test('floors a sub-second retry hint to one second', () async {
      final now = DateTime.utc(2026, 6, 23, 12);
      final limiter = InMemoryRateLimiter(
        limit: 1,
        window: const Duration(milliseconds: 200),
        dailyQuota: 100,
        now: () => now,
      );
      expect((await limiter.check('ip')).allowed, isTrue);
      final blocked = await limiter.check('ip');
      expect(blocked.allowed, isFalse);
      // The real wait is 200ms; Retry-After is whole seconds, so it floors to 1.
      expect(blocked.retryAfter, const Duration(seconds: 1));
    });

    test('separates clients by key', () async {
      final now = DateTime.utc(2026, 6, 23, 12);
      final limiter = InMemoryRateLimiter(
        limit: 1,
        window: const Duration(seconds: 60),
        dailyQuota: 100,
        now: () => now,
      );

      expect((await limiter.check('a')).allowed, isTrue);
      expect((await limiter.check('a')).allowed, isFalse);
      // A different client has its own budget.
      expect((await limiter.check('b')).allowed, isTrue);
    });

    test('refills as the sliding window advances', () async {
      var now = DateTime.utc(2026, 6, 23, 12);
      final limiter = InMemoryRateLimiter(
        limit: 1,
        window: const Duration(seconds: 10),
        dailyQuota: 100,
        now: () => now,
      );

      expect((await limiter.check('ip')).allowed, isTrue);
      expect((await limiter.check('ip')).allowed, isFalse);
      // After the window passes, the old hit no longer counts.
      now = now.add(const Duration(seconds: 11));
      expect((await limiter.check('ip')).allowed, isTrue);
    });

    test('enforces a daily quota independent of the window', () async {
      var now = DateTime.utc(2026, 6, 23);
      final limiter = InMemoryRateLimiter(
        limit: 100,
        window: const Duration(seconds: 1),
        dailyQuota: 2,
        now: () => now,
      );

      expect((await limiter.check('ip')).allowed, isTrue);
      now = now.add(const Duration(minutes: 5));
      expect((await limiter.check('ip')).allowed, isTrue);
      now = now.add(const Duration(minutes: 5));
      final blocked = await limiter.check('ip');
      expect(blocked.allowed, isFalse);
      // The daily retry hint points at the next UTC midnight.
      expect(blocked.retryAfter, const Duration(hours: 24) - const Duration(minutes: 10));
    });

    test('resets the daily quota at UTC midnight', () async {
      var now = DateTime.utc(2026, 6, 23, 23);
      final limiter = InMemoryRateLimiter(
        limit: 100,
        window: const Duration(seconds: 1),
        dailyQuota: 1,
        now: () => now,
      );

      expect((await limiter.check('ip')).allowed, isTrue);
      expect((await limiter.check('ip')).allowed, isFalse);
      // Crossing into the next UTC day clears the daily counter.
      now = DateTime.utc(2026, 6, 24, 0, 0, 1);
      expect((await limiter.check('ip')).allowed, isTrue);
    });

    test('a non-positive limit or quota disables that check', () async {
      final now = DateTime.utc(2026, 6, 23, 12);
      final limiter = InMemoryRateLimiter(
        limit: 0,
        window: const Duration(seconds: 60),
        dailyQuota: 0,
        now: () => now,
      );
      // Disabled: it always allows.
      for (var i = 0; i < 50; i++) {
        expect((await limiter.check('ip')).allowed, isTrue);
      }
    });

    test('the disabled limiter constant always allows', () async {
      const limiter = RateLimiter.disabled;
      for (var i = 0; i < 10; i++) {
        expect((await limiter.check('ip')).allowed, isTrue);
      }
    });
  });

  group('RateLimitDecision', () {
    test('the base constructor carries allowed and an optional retryAfter', () {
      const allow = RateLimitDecision(allowed: true);
      expect(allow.allowed, isTrue);
      expect(allow.retryAfter, isNull);
      const deny = RateLimitDecision(allowed: false, retryAfter: Duration(seconds: 5));
      expect(deny.allowed, isFalse);
      expect(deny.retryAfter, const Duration(seconds: 5));
    });
  });
}
