part of 'clip_resolve_cache.dart';

extension _ClipFrameResolution on ClipResolveCache {
  /// Frames extracted per store round-trip in streaming mode — small, so the
  /// extraction never holds a whole clip's frames in memory at once.
  static const int _extractChunk = 8;

  /// [meta] with its dimensions scaled down to fit [maxClipDecodeEdge] (keeping
  /// aspect, rounding each side to an even number decoders accept, never
  /// upscaling) — what the extractor decodes at. Unchanged when there is no
  /// bound or the source already fits.
  ///
  /// Only the dimensions move: fps, frame count, and the audio flag are probed
  /// facts the resampler, trim bounds, and audio collector read.
  ClipMetadata _boundedForDecode(ClipMetadata meta) {
    final bound = maxClipDecodeEdge;
    assert(bound == null || bound > 0, 'maxClipDecodeEdge must be positive; use null for no bound');
    if (bound == null || bound <= 0 || meta.width <= 0 || meta.height <= 0) return meta;
    final longEdge = math.max(meta.width, meta.height);
    if (longEdge <= bound) return meta;
    final scale = bound / longEdge;
    int even(int value) {
      final scaled = (value * scale).round();
      return scaled.isOdd ? scaled - 1 : scaled;
    }

    return (
      fps: meta.fps,
      frameCount: meta.frameCount,
      width: math.max(2, even(meta.width)),
      height: math.max(2, even(meta.height)),
      hasAudio: meta.hasAudio,
    );
  }

  Future<void> _resolveClipFrames(MediaSource source, Iterable<int> sourceFrames) async {
    final meta = await resolveClipMeta(source);
    final store = clipFrameStore;
    if (store == null) {
      final frames = clipFrames.putIfAbsent(source, () => {});
      final missing = [
        for (final i in sourceFrames)
          if (!frames.containsKey(i)) i,
      ];
      if (missing.isEmpty) return;
      final extracted = await extractClipFrames(source, missing, _boundedForDecode(meta));
      for (final entry in extracted.entries) {
        frames[entry.key] = await _decodeRawFrame(source, entry.value);
      }
      return;
    }
    await _streamer.extractMissing(
      source: source,
      sourceFrames: sourceFrames,
      meta: meta,
      store: store,
      extract: extractClipFrames,
      chunkSize: _extractChunk,
    );
  }

  ui.Image _decodedClipFrameLookup(MediaSource source, int sourceFrame) {
    assertResolved('decodedClipFrame');
    if (clipFrameStore == null) {
      final image = clipFrames[source]?[sourceFrame];
      if (image == null) {
        throw FluvieRenderException(
          '$runtimeType has no extracted clip frame $sourceFrame for "$source". '
          'Was it included in the frames pre-resolved with preResolveClip?',
        );
      }
      return image;
    }
    final image = _streamer.lookupDecoded(source, sourceFrame);
    if (image == null) {
      throw FluvieRenderException(
        '$runtimeType has no clip frame $sourceFrame for "$source" in the decode '
        'window. The capture loop must call prepareClipFrames(frame) before it '
        'pumps a frame that paints this clip.',
      );
    }
    return image;
  }

  void _retainPreviewClipFrames(Map<MediaSource, Set<int>> retained) {
    if (clipFrameStore != null) return;
    for (final source in clipFrames.keys.toList()) {
      final frames = clipFrames[source]!;
      for (final frame in frames.keys.toList()) {
        if (!(retained[source]?.contains(frame) ?? false)) frames.remove(frame)!.dispose();
      }
    }
  }
}
