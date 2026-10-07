import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';

final class _RangedDecoder implements RangedPcmDecoder {
  int fullCalls = 0;
  int rangedCalls = 0;
  Duration? requested;
  @override
  Future<PcmAudio> decode(AudioSource source) async {
    fullCalls++;
    throw StateError('unbounded');
  }

  @override
  Future<PcmAudio> decodeRange(
    AudioSource source, {
    required Duration start,
    required Duration duration,
  }) async {
    rangedCalls++;
    requested = duration;
    expect(start, Duration.zero);
    return (
      samples: Float64List((duration.inMicroseconds * 44100 / 1000000).ceil()),
      sampleRate: 44100,
    );
  }
}

void main() {
  test('default analysis shares only the used prefix with DSP lookahead', () async {
    final delegate = _RangedDecoder();
    final shared = SharedPcmDecoder(delegate);
    const source = AudioSource.file('/tmp/long_song.wav');
    await SpectralBeatDetectionService(decoder: shared).detect(source, fps: 30, totalFrames: 60);
    final table = await SpectralFrequencyAnalyzer(
      decoder: shared,
    ).analyze(source, fps: 30, totalFrames: 60);
    expect(table.totalFrames, 60);
    expect(delegate.fullCalls, 0);
    expect(delegate.rangedCalls, 1);
    expect(delegate.requested!.inMilliseconds, inInclusiveRange(2150, 2300));
    expect(shared.retainedBytes, lessThan(44100 * 3 * 8));
    shared.dispose();
  });
}
