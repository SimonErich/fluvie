part of 'ffmpeg_frame_extraction_service.dart';

/// Selects the session adapter and owns tools until the decoder opens.
Future<FrameExtractionSession> _openExtractionSession(
  FfmpegFrameExtractionService service,
  Uri source, {
  required int width,
  required int height,
  String? decoder,
  Future<void>? whenCancelled,
}) async {
  // Custom process runners keep their own process lifecycle and batch protocol.
  if (service._runner is! IoProcessRunner) {
    return _StatelessFrameSession(service, source, width, height, decoder);
  }
  final tools = FfmpegMediaTools(ffmpegPath: service.binaryPath, timeout: service.timeout);
  try {
    final session = await tools.openFrameSession(
      source,
      width: width,
      height: height,
      decoder: decoder,
      whenCancelled: whenCancelled,
    );
    return _NativeFrameSession(tools, session);
  } on Object {
    await tools.closeAsync();
    rethrow;
  }
}

final class _NativeFrameSession implements FrameExtractionSession {
  _NativeFrameSession(this.tools, this.session);
  final FfmpegMediaTools tools;
  final FfmpegFrameSession session;

  @override
  Future<Map<int, RawFrame>> extractFrames(Iterable<int> frameIndices) async {
    try {
      final frames = await session.readFrames(frameIndices);
      return {
        for (final entry in frames.entries)
          entry.key: RawFrame(
            frameIndex: entry.key,
            width: entry.value.width,
            height: entry.value.height,
            rgba: entry.value.rgba,
          ),
      };
    } on MediaCancelledException {
      throw const RenderCancelledException();
    } on MediaProcessException catch (error) {
      throw FluvieRenderException(error.toString());
    }
  }

  @override
  Future<void> close() async {
    await session.close();
    await tools.closeAsync();
  }
}

final class _StatelessFrameSession implements FrameExtractionSession {
  _StatelessFrameSession(this.service, this.source, this.width, this.height, this.decoder);
  final FrameExtractionService service;
  final Uri source;
  final int width;
  final int height;
  final String? decoder;
  @override
  Future<Map<int, RawFrame>> extractFrames(Iterable<int> frameIndices) =>
      service.extractFrames(source, frameIndices, width: width, height: height, decoder: decoder);
  @override
  Future<void> close() async {}
}
