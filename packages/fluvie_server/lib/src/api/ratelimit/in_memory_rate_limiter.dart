import 'dart:collection';

import 'package:fluvie_server/src/api/ratelimit/rate_limiter.dart';

/// An in-process [RateLimiter] combining a per-client sliding window with a
/// per-client daily quota, both keyed by the client IP.
///
/// The sliding window caps short bursts ([limit] calls per [window]); the
/// [dailyQuota] caps total calls per UTC day. A call is allowed only when it
/// passes both. State is process-local (lost on restart, not shared across
/// replicas), which is the right tradeoff for a single free-tier node: it needs
/// no datastore and the cost it guards (an LLM call) is itself per-process.
///
/// A non-positive [limit] disables the window check; a non-positive
/// [dailyQuota] disables the daily check; both non-positive yields an
/// always-allow limiter (equivalent to [RateLimiter.disabled]).
final class InMemoryRateLimiter implements RateLimiter {
  /// Creates the limiter. [now] is injected so tests drive a fixed clock
  /// instead of racing the wall clock.
  InMemoryRateLimiter({
    required this.limit,
    required this.window,
    required this.dailyQuota,
    DateTime Function()? now,
  }) : _now = now ?? _systemUtcNow;

  /// The maximum number of calls allowed within one [window] (per client).
  final int limit;

  /// The width of the sliding window.
  final Duration window;

  /// The maximum number of calls allowed per UTC day (per client).
  final int dailyQuota;

  final DateTime Function() _now;

  final Map<String, Queue<DateTime>> _hits = {};
  final Map<String, _DailyCount> _daily = {};

  @override
  Future<RateLimitDecision> check(String key) async {
    final now = _now();
    final dailyDeny = _checkDaily(key, now);
    if (dailyDeny != null) return dailyDeny;
    final windowDeny = _checkWindow(key, now);
    if (windowDeny != null) return windowDeny;
    _record(key, now);
    return const RateLimitDecision.allow();
  }

  RateLimitDecision? _checkWindow(String key, DateTime now) {
    if (limit <= 0) return null;
    final hits = _hits[key];
    if (hits == null) return null;
    final cutoff = now.subtract(window);
    while (hits.isNotEmpty && !hits.first.isAfter(cutoff)) {
      hits.removeFirst();
    }
    if (hits.length < limit) return null;
    final wait = hits.first.add(window).difference(now);
    return RateLimitDecision.deny(_atLeastOneSecond(wait));
  }

  RateLimitDecision? _checkDaily(String key, DateTime now) {
    if (dailyQuota <= 0) return null;
    final day = _dayKey(now);
    final entry = _daily[key];
    final count = entry != null && entry.day == day ? entry.count : 0;
    if (count < dailyQuota) return null;
    return RateLimitDecision.deny(_atLeastOneSecond(_untilNextDay(now)));
  }

  void _record(String key, DateTime now) {
    if (limit > 0) (_hits[key] ??= Queue<DateTime>()).add(now);
    if (dailyQuota > 0) {
      final day = _dayKey(now);
      final entry = _daily[key];
      _daily[key] = entry != null && entry.day == day
          ? _DailyCount(day, entry.count + 1)
          : _DailyCount(day, 1);
    }
  }

  static int _dayKey(DateTime now) {
    final utc = now.toUtc();
    return utc.year * 10000 + utc.month * 100 + utc.day;
  }

  static Duration _untilNextDay(DateTime now) {
    final utc = now.toUtc();
    final nextMidnight = DateTime.utc(utc.year, utc.month, utc.day).add(const Duration(days: 1));
    return nextMidnight.difference(utc);
  }

  static Duration _atLeastOneSecond(Duration wait) =>
      wait < const Duration(seconds: 1) ? const Duration(seconds: 1) : wait;

  // coverage:ignore-line: real wall clock; tests inject a fixed clock by contract.
  static DateTime _systemUtcNow() => DateTime.now().toUtc();
}

/// A client's call count within one UTC day.
final class _DailyCount {
  const _DailyCount(this.day, this.count);
  final int day;
  final int count;
}
