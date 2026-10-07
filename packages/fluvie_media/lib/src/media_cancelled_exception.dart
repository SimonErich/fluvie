/// A media operation stopped at its owner's request.
final class MediaCancelledException implements Exception {
  /// Creates the typed cancellation result.
  const MediaCancelledException();

  @override
  String toString() => 'Media operation cancelled';
}
