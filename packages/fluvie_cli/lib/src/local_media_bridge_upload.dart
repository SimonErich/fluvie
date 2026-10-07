part of 'local_media_bridge.dart';

extension _BridgeUpload on LocalMediaBridge {
  Future<_BridgeSource> _register(HttpRequest request) async {
    final pending = await _directory.createTemp('upload-');
    final file = File(p.join(pending.path, 'source.bin'));
    final sink = file.openWrite();
    final digestSink = _DigestSink();
    final digest = sha256.startChunkedConversion(digestSink);
    var bytes = 0;
    try {
      await for (final chunk in request) {
        bytes += chunk.length;
        if (bytes > 512 * 1024 * 1024) {
          throw const FormatException('A preview source exceeds 512 MiB.');
        }
        digest.add(chunk);
        sink.add(chunk);
      }
      digest.close();
      await sink.close();
      final id = digestSink.value!.toString();
      final existing = _sources[id];
      if (existing != null) {
        await pending.delete(recursive: true);
        return await existing;
      }
      final preparing = () async {
        final timeline = await _tools.probeTimeline(file.path, whenCancelled: _cancelled.future);
        final info = MediaSourceInfo.fromReport(
          await _tools.probeReport(file.path, whenCancelled: _cancelled.future),
          countedFrames: timeline.frameCount,
        );
        return _BridgeSource(id, file, info, timeline);
      }();
      _sources.addAll({id: preparing});
      try {
        return await preparing;
      } on Object {
        _sources.removeWhere((key, value) => key == id);
        rethrow;
      }
    } on Object {
      await sink.close();
      if (pending.existsSync()) await pending.delete(recursive: true);
      rethrow;
    }
  }
}

final class _BridgeSource {
  const _BridgeSource(this.id, this.file, this.info, this.timeline);
  final String id;
  final File file;
  final MediaSourceInfo info;
  final MediaTimeline timeline;
}

final class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}
