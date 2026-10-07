part of 'ffmpeg_media_tools.dart';

extension _MediaExtraction on FfmpegMediaTools {
  Future<Map<int, MediaFrame>> _extractFrames(
    Uri source,
    Iterable<int> indices, {
    required int width,
    required int height,
    String? decoder,
    int maxBytes = defaultFrameBatchBytes,
  }) async {
    final batches = frameBatches(indices, width: width, height: height, maxBytes: maxBytes);
    final path = FfmpegMediaTools._path('$source');
    if (decoder != null && (decoder.isEmpty || decoder.startsWith('-'))) {
      throw ArgumentError.value(decoder, 'decoder', 'must be a decoder name');
    }
    final frames = <int, MediaFrame>{};
    if (batches.isEmpty) return frames;
    final sandbox = await Directory.systemTemp.createTemp('fluvie_media_frames_');
    try {
      final output = File('${sandbox.path}${Platform.pathSeparator}frames.rgba');
      for (final batch in batches) {
        final result = await run(ffmpegPath, [
          '-v',
          'error',
          '-nostdin',
          ...FfmpegMediaTools._localInputProtocols,
          if (decoder != null) ...['-c:v', decoder],
          '-i',
          path,
          '-vf',
          frameSelectFilter(batch, width: width, height: height),
          '-fps_mode',
          'passthrough',
          '-frames:v',
          '${batch.length}',
          '-f',
          'rawvideo',
          '-pix_fmt',
          'rgba',
          '-y',
          'frames.rgba',
        ], workingDirectory: sandbox.path);
        if (result.exitCode != 0) {
          throw FfmpegMediaTools._failure(
            'Decoding frames ${batch.first}..${batch.last} of "$source"',
            result,
          );
        }
        if (!output.existsSync()) {
          throw MediaProcessException('FFmpeg wrote no frames for "$source".');
        }
        final bytes = await output.readAsBytes();
        final frameBytes = width * height * 4;
        if (bytes.length != frameBytes * batch.length) {
          throw MediaProcessException(
            'FFmpeg returned ${bytes.length} bytes for ${batch.length} frames of "$source"; '
            'expected ${frameBytes * batch.length}. Check source frame bounds.',
          );
        }
        for (var i = 0; i < batch.length; i++) {
          frames[batch[i]] = MediaFrame(
            frameIndex: batch[i],
            width: width,
            height: height,
            rgba: Uint8List.sublistView(bytes, i * frameBytes, (i + 1) * frameBytes),
          );
        }
      }
      return frames;
    } finally {
      if (sandbox.existsSync()) await sandbox.delete(recursive: true);
    }
  }
}
