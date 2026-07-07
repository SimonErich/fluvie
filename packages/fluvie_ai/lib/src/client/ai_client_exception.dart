/// Thrown when an `AiClient` call fails: a transport error, an auth failure,
/// or a malformed provider response.
final class AiClientException implements Exception {
  /// Creates an exception described by [message].
  AiClientException(this.message);

  /// What went wrong, in one actionable sentence.
  final String message;

  @override
  String toString() => 'AiClientException: $message';
}
