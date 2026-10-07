part of 'clip_resolve_cache.dart';

/// How a clip maps composition frames to its source frames — the data
/// [ClipResolveCache.prepareClipFramesForComposition] resamples against.
typedef _ClipPlan = ({
  int windowStart,
  int windowLength,
  int compFps,
  int trimStartFrames,
  int trimEndFrames,
  double trimStartOffsetFrames,
  double trimEndOffsetFrames,
  double speed,
  List<double>? sourceTimeMap,
});

/// The streaming-mode state behind [ClipResolveCache]: the per-clip plans and
/// store keys, which source frames already sit in the [ClipFrameStore], and
/// the bounded LRU window of decoded frames paint reads synchronously.
final class _ClipStreamer {
  final Map<MediaSource, List<_ClipPlan>> _plans = {};
  final Map<MediaSource, String> _keys = {};
  final Map<MediaSource, Set<int>> _storedFrames = {};
  final LinkedHashMap<String, ui.Image> _window = LinkedHashMap<String, ui.Image>();
  int _keyCounter = 0;

  bool get hasPlans => _plans.isNotEmpty;

  /// The opaque store key for [source], assigned on first use.
  String keyFor(MediaSource source) => _keys.putIfAbsent(source, () => 'clip${_keyCounter++}');

  /// Records one window [plan] for [source].
  ///
  /// A source can be painted by more than one element — the same clip in two
  /// scenes, or twice in one scene with different `show` windows — and each
  /// resamples from its own window start, so every plan is kept and warmed.
  /// Records compare by value, so re-registering an identical plan is a no-op
  /// and the contract's per-source idempotence holds.
  void registerPlan(MediaSource source, _ClipPlan plan) {
    final plans = _plans.putIfAbsent(source, () => <_ClipPlan>[]);
    if (!plans.contains(plan)) plans.add(plan);
  }

  /// How many windows are registered across every source — the floor on the
  /// decode window, since each one warms a frame per composition frame.
  int get _planCount => _plans.values.fold(0, (total, plans) => total + plans.length);

  /// Extracts the not-yet-stored [sourceFrames] of [source] into [store] in
  /// chunks of [chunkSize], via the resolver's [extract] callback.
  Future<void> extractMissing({
    required MediaSource source,
    required Iterable<int> sourceFrames,
    required ClipMetadata meta,
    required ClipFrameStore store,
    required Future<Map<int, RawFrame>> Function(MediaSource, List<int>, ClipMetadata) extract,
    required int chunkSize,
  }) async {
    final stored = _storedFrames.putIfAbsent(source, () => <int>{});
    final key = keyFor(source);
    final missing = [
      for (final i in sourceFrames)
        if (!stored.contains(i)) i,
    ]..sort();
    for (var i = 0; i < missing.length; i += chunkSize) {
      final chunk = missing.sublist(i, math.min(i + chunkSize, missing.length));
      final extracted = await extract(source, chunk, meta);
      for (final entry in extracted.entries) {
        await store.put(key, entry.key, entry.value.rgba);
        stored.add(entry.key);
      }
    }
  }

  /// Decodes (into the window) the frame every registered clip paints on
  /// composition frame [compFrame], loading from [store] on a miss.
  Future<void> prepareForComposition({
    required int compFrame,
    required Map<MediaSource, ClipMetadata> meta,
    required Map<MediaSource, MediaTimeline> timelines,
    required ClipFrameStore store,
    required int windowCapacity,
    required String debugOwner,
  }) async {
    for (final entry in _plans.entries) {
      final clipMeta = meta[entry.key];
      if (clipMeta == null) continue;
      for (final plan in entry.value) {
        if (plan.windowLength <= 0 || compFrame < plan.windowStart) continue;
        await _ensureDecoded(
          source: entry.key,
          sourceFrame: _resample(
            compFrame.clamp(plan.windowStart, plan.windowStart + plan.windowLength - 1),
            plan,
            clipMeta.fps,
            timelines[entry.key],
          ),
          store: store,
          meta: clipMeta,
          // Every registered window warms one frame per composition frame, so
          // the window must hold at least that many at once or a just-warmed
          // frame would be evicted before paint reads it.
          capacity: math.max(windowCapacity, _planCount),
          debugOwner: debugOwner,
        );
      }
    }
  }

  /// The decoded frame paint reads, or null when it is not in the window.
  ui.Image? lookupDecoded(MediaSource source, int sourceFrame) =>
      _window['${keyFor(source)}#$sourceFrame'];

  /// Disposes every decoded frame in the window and clears all per-clip state.
  void dispose() {
    for (final image in _window.values) {
      image.dispose();
    }
    _window.clear();
    _plans.clear();
    _keys.clear();
    _storedFrames.clear();
  }

  /// Ensures [sourceFrame] of [source] is decoded in the window, loading it
  /// from [store] and decoding on a miss, then evicting the LRU beyond
  /// [capacity].
  Future<void> _ensureDecoded({
    required MediaSource source,
    required int sourceFrame,
    required ClipFrameStore store,
    required ClipMetadata meta,
    required int capacity,
    required String debugOwner,
  }) async {
    final lruKey = '${keyFor(source)}#$sourceFrame';
    final present = _window.remove(lruKey);
    if (present != null) {
      _window[lruKey] = present; // touch: move to most-recently-used.
      return;
    }
    final rgba = await store.get(keyFor(source), sourceFrame);
    if (rgba == null) {
      throw FluvieRenderException(
        '$debugOwner has no stored clip frame $sourceFrame for "$source". '
        'Was it included in the frames pre-resolved with preResolveClip?',
      );
    }
    _window[lruKey] = await _decodeRgba(source, rgba, meta.width, meta.height);
    while (_window.length > capacity) {
      _window.remove(_window.keys.first)!.dispose();
    }
  }
}

/// The frame [plan] paints on composition frame [compFrame].
///
/// Delegates to the one resampling rule the painter uses, so the streamer can
/// never warm a different frame than paint asks for. It used to be a second
/// copy of that arithmetic; two copies is how a future rate parameter would
/// have desynced streaming from paint without a test noticing.
int _resample(int compFrame, _ClipPlan plan, double srcFps, MediaTimeline? timeline) =>
    resampleClipFrame(
      compFrame: compFrame,
      windowStart: plan.windowStart,
      compFps: plan.compFps,
      srcFps: srcFps,
      timeline: timeline,
      trimStartFrames: plan.trimStartFrames,
      trimEndFrames: plan.trimEndFrames,
      trimStartOffsetFrames: plan.trimStartOffsetFrames,
      trimEndOffsetFrames: plan.trimEndOffsetFrames,
      speed: plan.speed,
      sourceTimeMap: plan.sourceTimeMap,
    );

Future<ui.Image> _decodeRawFrame(MediaSource source, RawFrame raw) =>
    _decodeRgba(source, raw.rgba, raw.width, raw.height);

Future<ui.Image> _decodeRgba(MediaSource source, Uint8List rgba, int width, int height) async {
  try {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, width, height, ui.PixelFormat.rgba8888, completer.complete);
    return await completer.future;
  } on Object catch (error) {
    // coverage:ignore-line defensive decode failure wrap valid clip frames decode cleanly
    throw FluvieRenderException('Failed to decode clip frame of "$source": $error.');
  }
}
