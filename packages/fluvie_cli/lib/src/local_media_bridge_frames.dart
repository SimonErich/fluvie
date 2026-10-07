part of 'local_media_bridge.dart';

extension _BridgeFrames on LocalMediaBridge {
  Future<Map<int, MediaFrame>> _frames(HttpRequest request, _BridgeSource source) async {
    final raw = await LocalMediaBridge._body(request, limit: 64 * 1024);
    final requestData = jsonDecode(utf8.decode(raw)) as Map<String, Object?>;
    final width = requestData['width']! as int;
    final height = requestData['height']! as int;
    final indices = (requestData['indices']! as List<Object?>).cast<int>().toSet().toList()..sort();
    if (width <= 0 ||
        height <= 0 ||
        width * height * 4 * indices.length > defaultFrameBatchBytes ||
        indices.length > 512 ||
        indices.any((index) => index < 0 || index >= source.info.frameCount)) {
      throw const FormatException('Frame request exceeds source bounds or the 32 MiB batch limit.');
    }
    if (indices.isEmpty) return {};
    final operation = _frameTail.then((_) => _readFrames(source, indices, width, height));
    _frameTail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<Map<int, MediaFrame>> _readFrames(
    _BridgeSource source,
    List<int> indices,
    int width,
    int height,
  ) async {
    if (_closed) throw StateError('The preview media session is closed.');
    final key = '${source.id}:$width:$height';
    var session = _sessions.remove(key);
    if (session == null) {
      if (_sessions.length == 4) {
        final retired = _sessions.remove(_sessions.keys.first)!;
        await retired.close();
      }
      session = await _tools.openFrameSession(
        source.file.uri,
        width: width,
        height: height,
        decoder: source.info.codec == 'vp9' && source.info.hasAlpha ? 'libvpx-vp9' : null,
        whenCancelled: _cancelled.future,
      );
    }
    _sessions[key] = session;
    final starts = session.decoderStarts;
    try {
      return await session.readFrames(indices);
    } on Object {
      _sessions.remove(key);
      await session.close();
      rethrow;
    } finally {
      _decoderStarts += session.decoderStarts - starts;
    }
  }
}
