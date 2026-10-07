part of 'audio_preview_controller.dart';

extension _AudioPreviewLoading on AudioPreviewController {
  Future<void> _load(EditorDocument document) async {
    final epoch = ++_loadEpoch;
    _programLoading = true;
    _error = null;
    _notify();
    try {
      var tracks = audioTrackViews(document, VideoTimebase.of(document), clipMetadata: _metadata);
      for (final track in tracks) {
        if (_disposed || epoch != _loadEpoch) return;
        if (track.elementId != null && !_metadata.containsKey(track.sourceKey)) {
          final source = _source(track);
          final media = _mediaSource(source);
          await mediaResolver.preResolveAll([media]);
          _metadata[track.sourceKey] = await mediaResolver.probeClip(media);
        }
      }
      tracks = audioTrackViews(document, VideoTimebase.of(document), clipMetadata: _metadata);
      for (final track in tracks) {
        if (_disposed || epoch != _loadEpoch) return;
        if (track.unavailableReason != null) throw StateError(track.unavailableReason!);
        if (track.elementId != null && _metadata[track.sourceKey]?.hasAudio == false) continue;
        await _decode(track.sourceKey, _source(track));
      }
      if (_disposed || epoch != _loadEpoch) return;
      _tracks = tracks;
      _programLoading = false;
      _notify();
      _restart();
    } on Object catch (error) {
      if (!_disposed && epoch == _loadEpoch) {
        _programLoading = false;
        _tracks = [];
        _fail(error);
      }
    }
  }

  AudioSource _source(AudioTrackView track) {
    final bytes = bytesFor?.call(track.sourceKey);
    return bytes == null
        ? track.resolved.audioSource ?? track.spec.source
        : AudioSource.memory(bytes, debugLabel: track.sourceKey);
  }

  MediaSource _mediaSource(AudioSource source) => switch (source) {
    FileAudioSource(:final path) => MediaSource.file(path),
    AssetAudioSource(:final name) => MediaSource.asset(name),
    NetworkAudioSource(:final url) => MediaSource.network(url),
    MemoryAudioSource(:final bytes, :final debugLabel) => MediaSource.memory(
      bytes,
      debugLabel: debugLabel,
    ),
  };
  Future<PcmAudio> _decode(String key, AudioSource source) async {
    final cached = _pcm.remove(key);
    if (cached != null) {
      _pcm[key] = cached;
      return cached;
    }
    final pending = _pending[key];
    if (pending != null) return pending;
    final task = _platform.decode(source, resolver: mediaResolver, allowlist: networkAllowlist);
    _pending[key] = task;
    try {
      final pcm = await task;
      if (_disposed) return pcm;
      var bytes = _pcm.values.fold<int>(0, (sum, value) => sum + value.samples.lengthInBytes);
      while (_pcm.isNotEmpty && bytes + pcm.samples.lengthInBytes > 128 * 1024 * 1024) {
        final removed = _pcm.remove(_pcm.keys.first)!;
        bytes -= removed.samples.lengthInBytes;
      }
      _pcm[key] = pcm;
      _envelopes[key] = reduceToWaveform(pcm, buckets: 2048);
      _notify();
      return pcm;
    } finally {
      final removed = _pending.remove(key);
      if (removed != null) {
        unawaited(removed.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
      }
    }
  }
}
