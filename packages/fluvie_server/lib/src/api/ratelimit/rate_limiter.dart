import 'package:meta/meta.dart';

/// The outcome of a rate-limit [RateLimiter.check]: whether the call is
/// permitted and, when not, how long the caller should wait before retrying.
@immutable
final class RateLimitDecision {
  /// Creates a decision. [retryAfter] is `null` when [allowed] is `true`.
  const RateLimitDecision({required this.allowed, this.retryAfter});

  /// A permitted call (no wait).
  const RateLimitDecision.allow() : allowed = true, retryAfter = null;

  /// A rejected call that should retry after [wait].
  const RateLimitDecision.deny(Duration wait) : allowed = false, retryAfter = wait;

  /// Whether the call may proceed.
  final bool allowed;

  /// How long to wait before retrying, when [allowed] is `false`.
  final Duration? retryAfter;
}

/// Guards an expensive path (an LLM call) against per-client abuse.
///
/// Implementations decide whether a client identified by an opaque key (its IP)
/// may make another call right now. The abstract contract keeps the HTTP layer
/// testable: the handler depends on this, a fake scripts decisions, and the
/// real in-memory limiter is injected through the server factory.
abstract interface class RateLimiter {
  /// A limiter that never blocks, used when rate limiting is switched off.
  static const RateLimiter disabled = _DisabledRateLimiter();

  /// Records one call attempt for [key] and returns whether it is permitted.
  ///
  /// Calling this consumes budget only when the call is allowed, so a rejected
  /// caller is never charged for the rejection.
  Future<RateLimitDecision> check(String key);
}

/// The [RateLimiter.disabled] implementation: always allows.
final class _DisabledRateLimiter implements RateLimiter {
  const _DisabledRateLimiter();

  @override
  Future<RateLimitDecision> check(String key) async => const RateLimitDecision.allow();
}
