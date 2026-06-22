part of 'media_repository.dart';

/// The `dart:io` half of [MediaRepository]'s clip path: materialize the source
/// to a local file the probe and extractor can read by path. The cache, frame
/// diffing, decode, and lookups live in the shared [ClipResolveCache] mixin;
/// `probeClipSource` and `extractClipFrames` (in the main class) call this.
extension _ClipResolution on MediaRepository {
  /// Materializes [source], probes it for [ClipMetadata], and converts the
  /// probe result (ffprobe fps from frames over duration). The [ClipResolveCache]
  /// caches the result, so this runs once per source.
  Future<ClipMetadata> _probeClipSource(MediaSource source) async {
    final probe = probeService;
    if (probe == null) {
      throw FluvieRenderException(
        'MediaRepository cannot probe clip "$source" without a VideoProbeService. '
        'Wire it through the providers.',
      );
    }
    final path = await _materializeClip(source);
    final result = await probe.probe(path);
    final fps = result.durationSeconds > 0
        ? result.nbFrames / result.durationSeconds
        : result.nbFrames.toDouble();
    return (fps: fps, frameCount: result.nbFrames, width: result.width, height: result.height);
  }

  /// Extracts the [sourceFrames] of the already-materialized [source] at the clip
  /// [meta] dimensions through the ffmpeg [FrameExtractionService].
  Future<Map<int, RawFrame>> _extractClipFrames(
    MediaSource source,
    List<int> sourceFrames,
    ClipMetadata meta,
  ) async {
    final extractor = frameExtractor;
    if (extractor == null) {
      throw FluvieRenderException(
        'MediaRepository cannot resolve clip "$source" without a '
        'FrameExtractionService. Wire it through the providers.',
      );
    }
    return extractor.extractFrames(
      Uri.file(_clipPaths[source]!),
      sourceFrames,
      width: meta.width,
      height: meta.height,
    );
  }

  /// Loads the clip bytes once and writes them to a temp file the probe and
  /// extractor can read by path; cached per source.
  Future<String> _materializeClip(MediaSource source) async {
    final existing = _clipPaths[source];
    if (existing != null) return existing;
    final bytes = await loader.load(source);
    final dir = await Directory.systemTemp.createTemp('fluvie_clip_src_');
    final file = File('${dir.path}/clip.mp4');
    await file.writeAsBytes(bytes);
    return _clipPaths[source] = file.path;
  }
}
