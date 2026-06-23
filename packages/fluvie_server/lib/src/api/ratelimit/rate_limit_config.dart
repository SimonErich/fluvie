import 'package:meta/meta.dart';

/// The per-IP limits applied to the LLM-cost render path (prompt/edit), resolved
/// once from the environment by `serverConfigFromEnvironment`.
///
/// [limit] calls are allowed per [window] (the burst control) and [dailyQuota]
/// calls per UTC day (the free-tier ceiling). A non-positive [limit] or
/// [dailyQuota] switches that check off.
@immutable
final class RateLimitConfig {
  /// Creates a rate-limit config.
  const RateLimitConfig({
    required this.limit,
    required this.window,
    required this.dailyQuota,
  });

  /// The safe defaults applied when no rate-limit env is set: five LLM renders
  /// per minute per IP, fifty per UTC day.
  static const RateLimitConfig defaults = RateLimitConfig(
    limit: 5,
    window: Duration(minutes: 1),
    dailyQuota: 50,
  );

  /// The maximum LLM renders allowed within one [window] (per IP).
  final int limit;

  /// The width of the sliding window.
  final Duration window;

  /// The maximum LLM renders allowed per UTC day (per IP).
  final int dailyQuota;
}
