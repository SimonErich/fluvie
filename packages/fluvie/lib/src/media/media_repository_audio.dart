part of 'media_repository.dart';

/// Maps an [AudioSource] to the [MediaSource] the byte loader reads: the same
/// origin in the loader's vocabulary, so an asset key, file path, or
/// allowlisted URL flows through one validated path. The network case is gated
/// by the loader's allowlist exactly like image media.
MediaSource _audioMediaSource(AudioSource source) => switch (source) {
  AssetAudioSource(:final name) => MediaSource.asset(name),
  FileAudioSource(:final path) => MediaSource.file(path),
  NetworkAudioSource(:final url) => MediaSource.network(url),
};

/// The audio resolution path of [MediaRepository]: validate + allowlist each
/// source, then materialize its bytes to a local file the encoder can `-i`.
extension _AudioResolution on MediaRepository {
  /// Materializes every source in [sources] not already cached, writing its
  /// bytes to a temp file keyed by the source. A disallowed network host throws
  /// inside [MediaBytesLoader.load], before any file is written.
  Future<void> _resolveAudio(Iterable<AudioSource> sources) async {
    for (final source in sources) {
      if (_audioPaths.containsKey(source)) continue;
      _audioPaths[source] = await _materializeAudio(source);
    }
  }

  /// Materializes one source's bytes to a temp file keyed by its cache key,
  /// returning the file path. Network host gating happens inside the loader's
  /// allowlist check, exactly as image media does.
  Future<String> _materializeAudio(AudioSource source) async {
    final bytes = await loader.load(_audioMediaSource(source));
    final dir = await Directory.systemTemp.createTemp('fluvie_audio_src_');
    final file = File('${dir.path}/${source.cacheKey}');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}

/// The reactive-analysis path of [MediaRepository]: decode each source once and
/// run beat detection + frequency analysis over it, independent of the
/// encoder-file materialize concern.
extension _ReactiveResolution on MediaRepository {
  /// Analyses every source in [sources] not already analysed into a beat grid
  /// and a band table.
  ///
  /// Each source is materialized to a local file (reusing the audio materialize
  /// path) and the services are handed a [FileAudioSource] pointing at it, so
  /// the ffmpeg-backed decoder reads a real file while a test decoder ignores
  /// the path. Idempotent: an already-analysed source is skipped.
  Future<void> _resolveReactive(
    Iterable<AudioSource> sources, {
    required BeatDetectionService beatDetector,
    required FrequencyAnalyzer analyzer,
    required int fps,
    required int totalFrames,
  }) async {
    for (final source in sources) {
      if (_beatGrids.containsKey(source)) continue;
      final path = _audioPaths[source] ?? await _materializeAudio(source);
      _audioPaths[source] = path;
      final decodeSource = AudioSource.file(path);
      _beatGrids[source] = await beatDetector.detect(
        decodeSource,
        fps: fps,
        totalFrames: totalFrames,
      );
      _bandTables[source] = await analyzer.analyze(
        decodeSource,
        fps: fps,
        totalFrames: totalFrames,
      );
    }
  }
}
