/// Thrown by `ApiRenderClient` when a request fails: a non-2xx response, a
/// decode error, or a timeout while waiting for a render.
final class ApiClientException implements Exception {
  /// Creates the exception with a [message] and optional HTTP [statusCode].
  const ApiClientException(this.message, {this.statusCode});

  /// A human-readable description (the server's error message when available).
  final String message;

  /// The HTTP status code, when the failure came from a response.
  final int? statusCode;

  @override
  String toString() => statusCode == null
      ? 'ApiClientException: $message'
      : 'ApiClientException($statusCode): $message';
}
