/// The base error for every failure raised by this package.
///
/// Carries the human-readable [message], the [provider] that produced it, an
/// optional HTTP [statusCode], and an optional underlying [cause]. Concrete
/// subclasses narrow the failure mode (auth, rate limit, and so on) and give a
/// distinct [toString] label.
class AiException implements Exception {
  /// Creates an [AiException] for [provider] with [message].
  AiException(this.message, {required this.provider, this.statusCode, this.cause});

  /// A human-readable description of what went wrong.
  final String message;

  /// The provider id that produced this error (for example `openai`).
  final String provider;

  /// The HTTP status code, when the failure originated from a response.
  final int? statusCode;

  /// The underlying error or exception, when this wraps another failure.
  final Object? cause;

  /// The class label used to prefix [toString]; subclasses override this.
  String get _label => 'AiException';

  @override
  String toString() {
    final status = statusCode == null ? '' : ' (HTTP $statusCode)';
    return '$_label[$provider]$status: $message';
  }
}

/// Raised when the provider rejects the credentials (HTTP 401 or 403).
class AiAuthException extends AiException {
  /// Creates an [AiAuthException].
  AiAuthException(super.message, {required super.provider, super.statusCode, super.cause});

  @override
  String get _label => 'AiAuthException';
}

/// Raised when the provider rate-limits the request (HTTP 429).
class AiRateLimitException extends AiException {
  /// Creates an [AiRateLimitException], optionally carrying [retryAfter].
  AiRateLimitException(
    super.message, {
    required super.provider,
    super.statusCode,
    super.cause,
    this.retryAfter,
  });

  /// How long to wait before retrying, parsed from the `Retry-After` header.
  final Duration? retryAfter;

  @override
  String get _label => 'AiRateLimitException';
}

/// Raised when the request itself is invalid (HTTP 400 or 422).
class AiInvalidRequestException extends AiException {
  /// Creates an [AiInvalidRequestException].
  AiInvalidRequestException(
    super.message, {
    required super.provider,
    super.statusCode,
    super.cause,
  });

  @override
  String get _label => 'AiInvalidRequestException';
}

/// Raised for retryable failures: 5xx responses, network errors, or timeouts.
class AiTransientException extends AiException {
  /// Creates an [AiTransientException].
  AiTransientException(super.message, {required super.provider, super.statusCode, super.cause});

  @override
  String get _label => 'AiTransientException';
}

/// Raised when the provider returns a malformed or unexpected response body.
class AiResponseException extends AiException {
  /// Creates an [AiResponseException].
  AiResponseException(super.message, {required super.provider, super.statusCode, super.cause});

  @override
  String get _label => 'AiResponseException';
}

/// Raised when a long-running job poll exceeds its deadline.
class AiTimeoutException extends AiException {
  /// Creates an [AiTimeoutException].
  AiTimeoutException(super.message, {required super.provider, super.statusCode, super.cause});

  @override
  String get _label => 'AiTimeoutException';
}
