import 'package:ai_abstracted/src/core/ai_exception.dart';
import 'package:ai_abstracted/src/transport/retry_policy.dart';

/// The default retry predicate: transient and rate-limit failures only.
bool _isTransient(AiException error) =>
    error is AiTransientException || error is AiRateLimitException;

/// Runs [op] under [policy], retrying while [retryWhen] accepts the failure.
///
/// On a retryable [AiException] it sleeps `policy.delayFor(attempt)` (via the
/// injected [sleep], so tests pass `(_) async {}`) and tries again, up to
/// `policy.maxAttempts` total. The last failure is rethrown when attempts run
/// out or when [retryWhen] rejects it. Non-[AiException] throws propagate
/// immediately.
Future<T> withRetry<T>(
  RetryPolicy policy,
  Future<T> Function() op, {
  bool Function(AiException) retryWhen = _isTransient,
  Future<void> Function(Duration) sleep = Future.delayed,
}) async {
  var attempt = 0;
  while (true) {
    attempt++;
    try {
      return await op();
    } on AiException catch (error) {
      if (attempt >= policy.maxAttempts || !retryWhen(error)) {
        rethrow;
      }
      await sleep(policy.delayFor(attempt));
    }
  }
}
