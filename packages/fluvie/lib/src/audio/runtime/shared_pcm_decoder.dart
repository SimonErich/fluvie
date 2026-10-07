import 'dart:async';
import 'dart:typed_data';

import 'package:fluvie/src/audio/runtime/pcm_decoder.dart';
import 'package:fluvie/src/audio/runtime/ranged_pcm_decoder.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/dsp/wav_reader.dart';
import 'package:fluvie_media/fluvie_media.dart' show MediaCancelledException;

/// Shares one decode between audio analysis consumers in one preparation.
///
/// Equal sources share active work; failures retry on the next request. Completed
/// samples are read-only and retained within both budgets, with least recently
/// used sources evicted first. Create a new instance for each preparation, or
/// [clear] after changing source files. Nothing is cached across instances.
///
/// Retention budgets bound this wrapper's cache, not allocations inside the
/// injected decoder or samples held by callers. The caller owns the delegate's
/// process lifecycle; pass the same cancellation signal to a native delegate.
final class SharedPcmDecoder implements RangedPcmDecoder {
  /// Wraps [decoder], retaining one source and up to 128 MiB by default.
  ///
  /// Zero budgets disable completed retention while active work still coalesces.
  /// [whenCancelled] rejects waiting callers and releases this wrapper's samples.
  SharedPcmDecoder(
    PcmDecoder decoder, {
    this.maxBytes = 128 * 1024 * 1024,
    this.maxSources = 1,
    Future<void>? whenCancelled,
  }) : _decoder = decoder {
    if (maxBytes < 0) throw ArgumentError.value(maxBytes, 'maxBytes', 'must not be negative');
    if (maxSources < 0) throw ArgumentError.value(maxSources, 'maxSources', 'must not be negative');
    if (whenCancelled != null) {
      unawaited(
        whenCancelled.then((_) {
          _cancelled = true;
          dispose();
        }),
      );
    }
  }

  /// Maximum backing-buffer bytes retained after decoding.
  final int maxBytes;

  /// Maximum completed sources retained after decoding.
  final int maxSources;

  final PcmDecoder _decoder;
  final _retained = <_DecodeKey, PcmAudio>{};
  final _pending = <_DecodeKey, Completer<PcmAudio>>{};
  final _active = <Completer<PcmAudio>>{};
  var _bytes = 0;
  var _generation = 0;
  var _disposed = false;
  var _cancelled = false;

  /// Backing-buffer bytes currently retained by the completed source cache.
  int get retainedBytes => _bytes;

  /// Completed sources currently retained by this wrapper.
  int get retainedSources => _retained.length;

  /// Distinct active decodes still shared by this wrapper.
  int get pendingSources => _pending.length;

  @override
  Future<PcmAudio> decode(AudioSource source) =>
      _decode((source: source, start: null, duration: null));

  @override
  Future<PcmAudio> decodeRange(
    AudioSource source, {
    required Duration start,
    required Duration duration,
  }) async {
    if (start.isNegative || duration <= Duration.zero) {
      throw ArgumentError('Invalid audio source interval.');
    }
    if (_decoder is RangedPcmDecoder) {
      return _decode((source: source, start: start, duration: duration));
    }
    final pcm = await decode(source);
    final first = (start.inMicroseconds * pcm.sampleRate / 1000000).round().clamp(
      0,
      pcm.samples.length,
    );
    final end = ((start + duration).inMicroseconds * pcm.sampleRate / 1000000).round().clamp(
      first,
      pcm.samples.length,
    );
    if (first == 0 && end == pcm.samples.length) return pcm;
    return (
      samples: Float64List.fromList(pcm.samples.sublist(first, end)).asUnmodifiableView(),
      sampleRate: pcm.sampleRate,
    );
  }

  Future<PcmAudio> _decode(_DecodeKey source) async {
    await Future<void>.value();
    _checkOpen();
    final cached = _retained.remove(source);
    if (cached != null) {
      _retained[source] = cached;
      return cached;
    }
    return (_pending[source] ?? _start(source)).future;
  }

  Completer<PcmAudio> _start(_DecodeKey source) {
    final result = Completer<PcmAudio>();
    _pending[source] = result;
    _active.add(result);
    unawaited(_load(source, result, _generation));
    return result;
  }

  Future<void> _load(_DecodeKey source, Completer<PcmAudio> result, int generation) async {
    try {
      final pcm = source.duration == null
          ? await _decoder.decode(source.source)
          : await (_decoder as RangedPcmDecoder).decodeRange(
              source.source,
              start: source.start!,
              duration: source.duration!,
            );
      if (result.isCompleted) return;
      _checkOpen();
      final shared = (samples: pcm.samples.asUnmodifiableView(), sampleRate: pcm.sampleRate);
      if (generation == _generation) _remember(source, shared);
      result.complete(shared);
    } on Object catch (error, stack) {
      if (!result.isCompleted) result.completeError(error, stack);
    } finally {
      if (identical(_pending[source], result)) _pending.remove(source);
      _active.remove(result);
    }
  }

  void _remember(_DecodeKey source, PcmAudio pcm) {
    final bytes = pcm.samples.buffer.lengthInBytes;
    if (bytes > maxBytes || maxSources == 0 || maxBytes == 0) return;
    while (_retained.length >= maxSources || _bytes + bytes > maxBytes) {
      final oldest = _retained.remove(_retained.keys.first)!;
      _bytes -= oldest.samples.buffer.lengthInBytes;
    }
    _retained[source] = pcm;
    _bytes += bytes;
  }

  /// Releases completed samples and forgets active work without cancelling it.
  ///
  /// Existing callers still receive their results. Those results cannot refill
  /// the cache, and later requests start fresh decodes.
  void clear() {
    _generation++;
    _retained.clear();
    _pending.clear();
    _bytes = 0;
  }

  /// Releases retained samples and rejects active and future callers.
  ///
  /// Does not dispose the injected delegate. Calling repeatedly is harmless.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final active in _active) {
      active.completeError(_closedError);
    }
    _active.clear();
    clear();
  }

  void _checkOpen() {
    if (_disposed) _throwStopped();
  }

  Never _throwStopped() {
    if (_cancelled) throw const MediaCancelledException();
    throw StateError('The shared PCM decoder has been disposed.');
  }

  Object get _closedError => _cancelled
      ? const MediaCancelledException()
      : StateError('The shared PCM decoder has been disposed.');
}

typedef _DecodeKey = ({AudioSource source, Duration? start, Duration? duration});
