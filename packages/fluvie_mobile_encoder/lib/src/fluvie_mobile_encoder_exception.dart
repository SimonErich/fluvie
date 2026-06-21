/// Thrown when the on-device encoder fails.
///
/// Wraps the platform side's failure (a `PlatformException` from `MediaCodec`,
/// `MediaMuxer`, or `AVAssetWriter`) in one typed error, so callers never see a
/// raw channel exception. [code] is the platform error code when present.
final class FluvieMobileEncoderException implements Exception {
  /// Creates an encoder exception with a [message] and optional platform [code].
  const FluvieMobileEncoderException(this.message, {this.code});

  /// A human-readable description of what failed.
  final String message;

  /// The platform error code, when the failure came from the native side.
  final String? code;

  @override
  String toString() {
    final tag = code == null
        ? 'FluvieMobileEncoderException'
        : 'FluvieMobileEncoderException($code)';
    return '$tag: $message';
  }
}
