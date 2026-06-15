part of 'media_repository.dart';

/// Whether [source]'s name reads as a clip (a video container) rather than an
/// image, by file extension. The image pre-resolve pass (`preResolveAll`) uses
/// it to skip the image decode for clip sources — those resolve through the
/// clip path (`preResolveClip`) instead.
bool _isClipSource(MediaSource source) {
  final name = switch (source) {
    AssetSource(:final name) => name,
    FileSource(:final path) => path,
    NetworkSource(:final url) => url.path,
    MemorySource() => '',
  };
  final lower = name.toLowerCase();
  return lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.webm');
}

/// The clip resolution path of [MediaRepository]: materialize the source to a
/// local file, probe it, and extract the listed frames.
extension _ClipResolution on MediaRepository {
  /// Probes [source] and extracts every frame in [sourceFrames] not already
  /// cached, decoding each to a `ui.Image` keyed by `(source, frame)`.
  Future<void> _resolveClip(MediaSource source, Iterable<int> sourceFrames) async {
    final probe = probeService;
    final extractor = frameExtractor;
    if (probe == null || extractor == null) {
      throw FluvieRenderException(
        'MediaRepository cannot resolve clip "$source" without a VideoProbeService '
        'and a FrameExtractionService. Wire them through the providers.',
      );
    }
    final path = await _materializeClip(source);
    final meta = _clipMeta[source] ?? await _probeClip(source, path, probe);
    final frames = _clipFrames.putIfAbsent(source, () => {});
    for (final index in sourceFrames) {
      if (frames.containsKey(index)) continue;
      final raw = await extractor.extractFrame(
        Uri.file(path),
        index,
        width: meta.width,
        height: meta.height,
      );
      frames[index] = await _decodeClipFrame(source, raw);
    }
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

  Future<ClipMetadata> _probeClip(
    MediaSource source,
    String path,
    VideoProbeService probe,
  ) async {
    final result = await probe.probe(path);
    final fps = result.durationSeconds > 0
        ? result.nbFrames / result.durationSeconds
        : result.nbFrames.toDouble();
    return _clipMeta[source] = (
      fps: fps,
      frameCount: result.nbFrames,
      width: result.width,
      height: result.height,
    );
  }

  /// The extracted-or-throw lookup behind `decodedClipFrame`: asserts the
  /// pre-pass ran, then returns the cached frame or a typed error naming it.
  ui.Image _decodedClipFrame(MediaSource source, int sourceFrame) {
    _assertResolved('decodedClipFrame');
    final image = _clipFrames[source]?[sourceFrame];
    if (image == null) {
      throw FluvieRenderException(
        'MediaRepository has no extracted clip frame $sourceFrame for "$source". '
        'Was it included in the frames pre-resolved with preResolveClip?',
      );
    }
    return image;
  }

  Future<ui.Image> _decodeClipFrame(MediaSource source, RawFrame raw) async {
    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        raw.rgba,
        raw.width,
        raw.height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      return await completer.future;
    } on Object catch (error) {
      // coverage:ignore-line: defensive decode-failure wrap; valid clip bytes decode cleanly
      throw FluvieRenderException('Failed to decode clip frame of "$source": $error.');
    }
  }
}
