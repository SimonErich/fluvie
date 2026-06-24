import 'package:meta/meta.dart';

/// An exponential-backoff retry policy with bounded, deterministic jitter.
///
/// [delayFor] returns `baseDelay * 2^(attempt - 1)`, clamped to [maxDelay] and
/// spread by up to ±[jitter] of that value. The jitter is derived from the
/// attempt number rather than a random source, so backoff is reproducible in
/// tests while still staggering retries in practice.
@immutable
final class RetryPolicy {
  /// Creates a [RetryPolicy].
  ///
  /// [maxAttempts] caps total tries, [baseDelay] is the first backoff step,
  /// [maxDelay] caps the curve, and [jitter] is the fractional spread (0..1).
  const RetryPolicy({
    this.maxAttempts = 4,
    this.baseDelay = const Duration(milliseconds: 400),
    this.maxDelay = const Duration(seconds: 8),
    this.jitter = 0.2,
  });

  /// The maximum number of attempts before giving up.
  final int maxAttempts;

  /// The delay before the first retry; later steps double from here.
  final Duration baseDelay;

  /// The hard ceiling the exponential curve is clamped to.
  final Duration maxDelay;

  /// The fractional jitter band (0..1) applied around each step.
  final double jitter;

  /// The backoff [Duration] before the [attempt]-th retry (1-based).
  ///
  /// Attempts below 1 clamp to the first step. The result is bounded by
  /// [maxDelay] and offset by a deterministic jitter within ±[jitter].
  Duration delayFor(int attempt) {
    final step = attempt < 1 ? 1 : attempt;
    // Cap the shift so large attempts never overflow the int before clamping.
    final shift = (step - 1).clamp(0, 30);
    final exponential = baseDelay.inMilliseconds * (1 << shift);
    final capped = exponential > maxDelay.inMilliseconds ? maxDelay.inMilliseconds : exponential;
    final offset = (capped * jitter * _signedJitter(step)).round();
    return Duration(milliseconds: capped + offset);
  }

  /// A deterministic value in `[-1, 1]` derived from [step].
  double _signedJitter(int step) {
    // A cheap, stable hash spread across the band; never random.
    final scaled = (step * 2654435761) % 2000;
    return scaled / 1000.0 - 1.0;
  }
}

/// Whether an HTTP [code] should be retried (429 rate-limit or any 5xx).
bool retryableStatus(int code) => code == 429 || (code >= 500 && code < 600);
