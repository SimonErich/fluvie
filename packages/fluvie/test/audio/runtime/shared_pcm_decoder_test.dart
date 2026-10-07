import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show AudioSource;
import 'package:fluvie/rendering.dart';
import 'package:fluvie_media/fluvie_media.dart' show MediaCancelledException;

final class _Decoder implements PcmDecoder {
  _Decoder(this.read);
  final Future<PcmAudio> Function(AudioSource) read;
  final calls = <AudioSource>[];

  @override
  Future<PcmAudio> decode(AudioSource source) {
    calls.add(source);
    return read(source);
  }
}

PcmAudio _pcm([int count = 4]) => (samples: Float64List(count), sampleRate: 44100);

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  const first = AudioSource.file('/first.wav');
  const second = AudioSource.file('/second.wav');

  test('beats and bands reuse one decode, with read-only shared samples', () async {
    final delegate = _Decoder((_) async => _pcm(2048));
    final shared = SharedPcmDecoder(delegate);
    final beats = SpectralBeatDetectionService(decoder: shared);
    final bands = SpectralFrequencyAnalyzer(decoder: shared);
    final grid = await beats.detect(first, fps: 30, totalFrames: 30);
    final table = await bands.analyze(first, fps: 30, totalFrames: 30);
    expect(delegate.calls, [first]);
    expect(shared.retainedSources, 1);
    expect(shared.retainedBytes, 2048 * 8);
    final pcm = await shared.decode(first);
    expect(() => pcm.samples[0] = 1, throwsUnsupportedError);
    shared.dispose();
    expect(shared.retainedBytes, 0);
    expect(grid.firstBeatAtOrAfter(0), isNull);
    expect(table.totalFrames, 30);
  });

  test('concurrent equal requests coalesce and distinct sources remain independent', () async {
    final pending = <AudioSource, Completer<PcmAudio>>{};
    final delegate = _Decoder((source) => (pending[source] ??= Completer<PcmAudio>()).future);
    final shared = SharedPcmDecoder(delegate, maxSources: 2);
    final a = shared.decode(first);
    final b = shared.decode(const AudioSource.file('/first.wav'));
    final c = shared.decode(second);
    await _flush();
    expect(delegate.calls, [first, second]);
    expect(shared.pendingSources, 2);
    pending[first]!.complete(_pcm());
    pending[second]!.complete(_pcm(8));
    final values = await Future.wait([a, b, c]);
    expect(values[0].samples, same(values[1].samples));
    expect(values[2].samples.length, 8);
    expect(shared.pendingSources, 0);
    shared.dispose();
  });

  test('failed decodes are not retained and the next request retries', () async {
    var attempts = 0;
    final delegate = _Decoder((_) async {
      if (++attempts == 1) throw StateError('bad source');
      return _pcm();
    });
    final shared = SharedPcmDecoder(delegate);
    await expectLater(shared.decode(first), throwsStateError);
    expect(shared.pendingSources, 0);
    expect(shared.retainedBytes, 0);
    await Future.wait([shared.decode(first), shared.decode(first)]);
    expect(delegate.calls.length, 2);
    shared.dispose();
  });

  test('evicts least recently used sources within both retention budgets', () async {
    const third = AudioSource.file('/third.wav');
    final delegate = _Decoder((_) async => _pcm());
    final shared = SharedPcmDecoder(delegate, maxBytes: 64, maxSources: 2);
    await shared.decode(first);
    await shared.decode(second);
    await shared.decode(first);
    await shared.decode(third);
    expect(shared.retainedBytes, 64);
    expect(shared.retainedSources, 2);
    await shared.decode(second);
    expect(delegate.calls, [first, second, third, second]);
    shared.dispose();
  });

  test('oversized backing buffers are returned without being retained', () async {
    final backing = Float64List(16);
    final delegate = _Decoder(
      (_) async => (samples: Float64List.view(backing.buffer, 0, 1), sampleRate: 44100),
    );
    final shared = SharedPcmDecoder(delegate, maxBytes: 16);
    expect((await shared.decode(first)).samples.length, 1);
    await shared.decode(first);
    expect(delegate.calls.length, 2);
    expect(shared.retainedBytes, 0);
    shared.dispose();
  });

  test('the byte budget evicts data even when the source limit has room', () async {
    final delegate = _Decoder((_) async => _pcm());
    final shared = SharedPcmDecoder(delegate, maxBytes: 32, maxSources: 5);
    await shared.decode(first);
    await shared.decode(second);
    expect(shared.retainedSources, 1);
    expect(shared.retainedBytes, 32);
    await shared.decode(first);
    expect(delegate.calls, [first, second, first]);
    shared.dispose();
  });

  test('zero retention still coalesces active work', () async {
    final pending = Completer<PcmAudio>();
    final delegate = _Decoder((_) => pending.future);
    final shared = SharedPcmDecoder(delegate, maxBytes: 0);
    final a = shared.decode(first);
    final b = shared.decode(first);
    await _flush();
    expect(delegate.calls.length, 1);
    pending.complete(_pcm());
    await Future.wait([a, b]);
    expect(shared.retainedSources, 0);
    await shared.decode(first);
    expect(delegate.calls.length, 2);
    shared.dispose();
  });

  test('clear releases retained data and prevents old active work repopulating it', () async {
    final pending = <Completer<PcmAudio>>[];
    final delegate = _Decoder((_) {
      final result = Completer<PcmAudio>();
      pending.add(result);
      return result.future;
    });
    final shared = SharedPcmDecoder(delegate);
    final old = shared.decode(first);
    await _flush();
    shared.clear();
    final fresh = shared.decode(first);
    await _flush();
    pending[0].complete(_pcm());
    await old;
    expect(shared.retainedSources, 0);
    expect(shared.pendingSources, 1);
    pending[1].complete(_pcm(8));
    expect((await fresh).samples.length, 8);
    expect(shared.retainedBytes, 64);
    shared.clear();
    expect(shared.retainedBytes, 0);
    shared.dispose();
  });

  test('dispose rejects pending and future callers without owning an injected delegate', () async {
    final pending = Completer<PcmAudio>();
    final shared = SharedPcmDecoder(_Decoder((_) => pending.future));
    final result = shared.decode(first);
    await _flush();
    final failure = expectLater(result, throwsStateError);
    shared.dispose();
    await failure;
    await expectLater(shared.decode(first), throwsStateError);
    pending.complete(_pcm());
    await _flush();
    shared.dispose();
    expect(shared.pendingSources, 0);
    expect(shared.retainedBytes, 0);
  });

  test('dispose also rejects callers whose active decode was forgotten by clear', () async {
    final pending = Completer<PcmAudio>();
    final shared = SharedPcmDecoder(_Decoder((_) => pending.future));
    final result = shared.decode(first);
    await _flush();
    shared.clear();
    final failure = expectLater(result, throwsStateError);
    shared.dispose();
    await failure;
    pending.complete(_pcm());
    await _flush();
    expect(shared.retainedBytes, 0);
  });

  test('cancellation rejects active work immediately and drops completed retention', () async {
    final cancelled = Completer<void>();
    final pending = Completer<PcmAudio>();
    final delegate = _Decoder((source) async => source == first ? _pcm() : pending.future);
    final shared = SharedPcmDecoder(delegate, whenCancelled: cancelled.future);
    await shared.decode(first);
    final active = shared.decode(second);
    await _flush();
    final failure = expectLater(active, throwsA(isA<MediaCancelledException>()));
    cancelled.complete();
    await failure;
    expect(shared.retainedBytes, 0);
    await expectLater(shared.decode(first), throwsA(isA<MediaCancelledException>()));
    pending.complete(_pcm());
    await _flush();
    shared.dispose();
  });

  test('pre-cancelled scopes do not call the delegate', () async {
    final delegate = _Decoder((_) async => _pcm());
    final shared = SharedPcmDecoder(delegate, whenCancelled: Future<void>.value());
    await expectLater(shared.decode(first), throwsA(isA<MediaCancelledException>()));
    expect(delegate.calls, isEmpty);
  });

  test('a new preparation has its own source identity and decoded data', () async {
    var version = 0;
    final delegate = _Decoder(
      (_) async => (samples: Float64List.fromList([(++version).toDouble()]), sampleRate: 1),
    );
    final a = SharedPcmDecoder(delegate);
    final b = SharedPcmDecoder(delegate);
    expect((await a.decode(first)).samples.single, 1);
    expect((await b.decode(first)).samples.single, 2);
    expect((await a.decode(first)).samples.single, 1);
    a.dispose();
    b.dispose();
  });

  test('validates retention bounds and supports disabling the source cache', () async {
    final delegate = _Decoder((_) async => _pcm());
    expect(() => SharedPcmDecoder(delegate, maxBytes: -1), throwsArgumentError);
    expect(() => SharedPcmDecoder(delegate, maxSources: -1), throwsArgumentError);
    final shared = SharedPcmDecoder(delegate, maxSources: 0);
    await shared.decode(first);
    expect(shared.retainedSources, 0);
    shared.dispose();
  });
}
