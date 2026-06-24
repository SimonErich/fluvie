import 'package:ai_abstracted/src/core/ai_exception.dart';

/// Maps a non-2xx HTTP [status] to the matching [AiException] subtype.
///
/// [provider] labels the error, [message] describes it, [headers] is consulted
/// for `Retry-After` on 429, and [cause] preserves any underlying error. The
/// status ranges follow the package contract: 401/403 -> auth, 429 -> rate
/// limit, 400/422 -> invalid request, 5xx -> transient, everything else ->
/// a bare [AiException].
AiException mapStatusToException(
  int status, {
  required String provider,
  required String message,
  Map<String, String> headers = const {},
  Object? cause,
}) {
  switch (status) {
    case 401:
    case 403:
      return AiAuthException(message, provider: provider, statusCode: status, cause: cause);
    case 429:
      return AiRateLimitException(
        message,
        provider: provider,
        statusCode: status,
        cause: cause,
        retryAfter: parseRetryAfter(headers['retry-after']),
      );
    case 400:
    case 422:
      return AiInvalidRequestException(
        message,
        provider: provider,
        statusCode: status,
        cause: cause,
      );
    default:
      if (status >= 500 && status < 600) {
        return AiTransientException(message, provider: provider, statusCode: status, cause: cause);
      }
      return AiException(message, provider: provider, statusCode: status, cause: cause);
  }
}

/// Parses a `Retry-After` header [value] (delta-seconds form) to a [Duration].
///
/// Returns null when [value] is absent or not a non-negative integer count of
/// seconds. The HTTP-date form is intentionally not supported.
Duration? parseRetryAfter(String? value) {
  if (value == null) {
    return null;
  }
  final seconds = int.tryParse(value.trim());
  if (seconds == null || seconds < 0) {
    return null;
  }
  return Duration(seconds: seconds);
}
