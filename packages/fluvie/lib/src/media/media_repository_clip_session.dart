part of 'media_repository.dart';

extension _RepositoryFrameSessions on MediaRepository {
  Future<Map<int, RawFrame>> _extractViaSession(
    FrameExtractionSessionService factory,
    MediaSource source,
    ClipMetadata meta,
    Iterable<int> missing,
  ) async {
    final key = (
      source: source,
      width: meta.width,
      height: meta.height,
      decoder: _clipDecoders[source],
    );
    final pending = _frameSessions.putIfAbsent(
      key,
      () => factory
          .openSession(
            Uri.file(_clipPaths[source]!),
            width: meta.width,
            height: meta.height,
            decoder: _clipDecoders[source],
            whenCancelled: Future.any([
              _released.future,
              ?whenCancelled,
            ]),
          )
          .then(_FrameSessionLease.new),
    );
    try {
      final lease = await pending;
      if (_released.isCompleted) {
        await lease.close();
        throw const RenderCancelledException();
      }
      _activeFrameSessions.add(lease);
      return await lease.session.extractFrames(missing);
    } on Object {
      unawaited(_frameSessions.remove(key));
      unawaited(
        pending.then((lease) async {
          _activeFrameSessions.remove(lease);
          await lease.close();
        }, onError: (Object _, StackTrace _) {}),
      );
      rethrow;
    }
  }
}

// Repository ownership is idempotent even if release races a failed batch.
final class _FrameSessionLease {
  _FrameSessionLease(this.session);
  final FrameExtractionSession session;
  Future<void>? _closing;

  Future<void> close() => _closing ??= session.close();
}
