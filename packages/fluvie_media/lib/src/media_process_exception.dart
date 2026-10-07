/// A media failure with the source and native process diagnostic preserved.
final class MediaProcessException implements Exception {
  /// Creates an actionable process failure.
  const MediaProcessException(this.message, {this.exitCode, this.stderr = ''});

  /// Human-readable operation and source.
  final String message;

  /// Native exit status, when available.
  final int? exitCode;

  /// Last 4 KiB of stderr.
  final String stderr;

  @override
  String toString() => '$message${stderr.isEmpty ? '' : '\n$stderr'}';
}
