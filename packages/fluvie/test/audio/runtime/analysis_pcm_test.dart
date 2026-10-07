import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/audio/runtime/analysis_pcm.dart';

final class _LegacyDecoder implements PcmDecoder {
  int calls = 0;
  final PcmAudio pcm = (
    samples: Float64List.fromList(List.generate(100, (i) => i.toDouble())),
    sampleRate: 100,
  );
  @override
  Future<PcmAudio> decode(AudioSource source) async {
    calls++;
    return pcm;
  }
}

void main() {
  test('legacy decoders preserve prefixes and slice trims with the shared lookahead', () async {
    final decoder = _LegacyDecoder();
    const source = AudioSource.file('song.wav');
    expect(await decodeAnalysisPcm(decoder, source, fps: 10, totalFrames: 1), same(decoder.pcm));
    final trimmed = await decodeAnalysisPcm(
      decoder,
      source,
      fps: 10,
      totalFrames: 1,
      start: const Duration(milliseconds: 500),
    );
    expect(trimmed.samples, List.generate(35, (i) => (50 + i).toDouble()));
    final eof = await decodeAnalysisPcm(
      decoder,
      source,
      fps: 10,
      totalFrames: 10,
      start: const Duration(seconds: 2),
    );
    expect(eof.samples, isEmpty);
    expect(decoder.pcm.samples.length, 100);
  });
  test('invalid analysis windows fail before consulting a decoder', () async {
    final decoder = _LegacyDecoder();
    for (final options in [
      (0, 1, Duration.zero),
      (1, 0, Duration.zero),
      (1, 1, const Duration(seconds: -1)),
    ]) {
      await expectLater(
        decodeAnalysisPcm(
          decoder,
          const AudioSource.file('song.wav'),
          fps: options.$1,
          totalFrames: options.$2,
          start: options.$3,
        ),
        throwsArgumentError,
      );
    }
    expect(decoder.calls, 0);
  });
}
