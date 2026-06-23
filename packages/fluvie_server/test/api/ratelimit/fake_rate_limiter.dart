import 'package:fluvie_server/src/api/ratelimit/rate_limiter.dart';

/// A scripted [RateLimiter] for handler tests: it records every key it is asked
/// about and returns the configured [decision] (allow by default).
final class FakeRateLimiter implements RateLimiter {
  /// Creates the fake. [decision] is the canned answer for every [check].
  FakeRateLimiter({this.decision = const RateLimitDecision.allow()});

  /// The keys this limiter was asked about, in call order.
  final List<String> calls = [];

  /// The decision returned for every call.
  final RateLimitDecision decision;

  @override
  Future<RateLimitDecision> check(String key) async {
    calls.add(key);
    return decision;
  }
}
