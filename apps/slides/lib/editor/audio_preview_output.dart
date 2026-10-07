part of 'audio_preview_controller.dart';

extension AudioPreviewOutput on AudioPreviewController {
  void _cancelOutput() {
    _epoch++;
    _chunkEnd = -1;
    unawaited(_platform.stop().catchError(_fail));
  }

  void _mixChanged() {
    _cancelOutput();
    _restart();
  }

  void _stateChanged() {
    final transport = _transport;
    if (transport == null || !transport.isPlaying) {
      if (!_auditioning) _cancelOutput();
      return;
    }
    _platform.unlock();
    if (_auditioning) stopAudition();
    if (_chunkEnd < 0) _restart();
  }

  void _frameChanged() {
    final transport = _transport;
    if (transport == null || !transport.isPlaying) return;
    final frame = transport.frame;
    final jumped = frame < _lastFrame || frame - _lastFrame > math.max(3, transport.fps ~/ 2);
    _lastFrame = frame;
    if (jumped) {
      _cancelOutput();
      _restart();
    } else if ((frame + _absoluteOffset) / transport.fps >= _chunkEnd && _chunkEnd >= 0) {
      _restart();
    }
  }

  void _restart() {
    final transport = _transport;
    if (_disposed ||
        _programLoading ||
        _auditioning ||
        transport == null ||
        !transport.isPlaying ||
        _tracks.isEmpty) {
      return;
    }
    final start = (transport.frame + _absoluteOffset) / transport.fps;
    final end = (transport.length + _absoluteOffset) / transport.fps;
    final duration = math.min<double>(30, end - start);
    if (duration <= 0) return;
    _chunkEnd = start + duration;
    final epoch = ++_epoch;
    unawaited(_renderChunk(start, duration, epoch));
  }

  Future<void> _renderChunk(double start, double duration, int epoch) async {
    try {
      final inputs = <AudioPreviewTrack>[];
      var liveBytes = 0;
      for (final track in _tracks) {
        if (track.resolved.volume == 0 ||
            monitor.gainForLane(track.spec.lane) == 0 ||
            track.span.end / (_document?.spec.fps ?? 30) <= start ||
            track.span.start / (_document?.spec.fps ?? 30) >= start + duration) {
          continue;
        }
        final pcm = await _decode(track.sourceKey, _source(track));
        if (_disposed || epoch != _epoch) return;
        liveBytes += pcm.samples.lengthInBytes;
        if (liveBytes > 128 * 1024 * 1024) {
          throw StateError('Simultaneous audio sources exceed the preview memory budget');
        }
        inputs.add(
          AudioPreviewTrack(
            audio: pcm,
            track: track.resolved,
            monitorGain: monitor.gainForLane(track.spec.lane),
          ),
        );
      }
      if (_disposed || epoch != _epoch) return;
      final now = ((_transport?.frame ?? 0) + _absoluteOffset) / (_transport?.fps ?? 30);
      final actualStart = math.max(start, now);
      final remaining = start + duration - actualStart;
      if (remaining <= 0) {
        _chunkEnd = -1;
        _restart();
        return;
      }
      final wav = renderAudioPreviewWav(
        tracks: inputs,
        startSeconds: actualStart,
        durationSeconds: remaining,
        sampleRate: 22050,
      );
      _play(wav, epoch);
    } on Object catch (error) {
      if (epoch == _epoch) _fail(error);
    }
  }

  void _play(Uint8List wav, int epoch) {
    unawaited(
      _platform
          .play(wav)
          .then((_) {
            if (!_disposed && epoch == _epoch && _auditioning) {
              _auditioning = false;
              _notify();
            }
          })
          .catchError((Object error) {
            if (epoch == _epoch) _fail(error);
          }),
    );
  }

  /// Auditions up to 30 seconds of an asset from its source-rate frame.
  Future<void> audition(MediaStoreEntry entry, {int frame = 0}) async {
    _transport?.pause();
    _cancelOutput();
    _platform.unlock();
    final epoch = ++_epoch;
    _auditioning = true;
    _loading = true;
    _error = null;
    _notify();
    try {
      final key = entry.source['value']! as String;
      final bytes = bytesFor?.call(key);
      final source = bytes != null
          ? AudioSource.memory(bytes, debugLabel: key)
          : AudioTrackSpec.fromJson({
              'kind': 'music',
              'source': entry.source,
            }, _document?.spec.anchors ?? AnchorTable()).source;
      final pcm = await _decode(key, source);
      if (_disposed || epoch != _epoch) return;
      final start = frame / (entry.fps ?? _document?.spec.fps.toDouble() ?? 30);
      final duration = math.min<double>(30, pcm.samples.length / pcm.sampleRate - start);
      _loading = false;
      if (duration <= 0) {
        _auditioning = false;
        _notify();
        return;
      }
      _notify();
      _play(
        renderAudioPreviewWav(
          tracks: [
            AudioPreviewTrack(
              audio: pcm,
              track: ResolvedAudioTrack(source: key),
            ),
          ],
          startSeconds: start,
          durationSeconds: duration,
          sampleRate: 22050,
        ),
        epoch,
      );
    } on Object catch (error) {
      if (epoch == _epoch) {
        _loading = false;
        _auditioning = false;
        _fail(error);
      }
    }
  }

  void stopAudition() {
    _auditioning = false;
    _loading = false;
    _cancelOutput();
    _notify();
  }
}
