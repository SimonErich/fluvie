import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show AudioSource;
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/rendering/preparation_audio_io.dart';

final class _Decoder implements PcmDecoder {
  int calls = 0;

  @override
  Future<PcmAudio> decode(AudioSource source) async {
    calls++;
    return (samples: Float64List(2048), sampleRate: 44100);
  }
}

void main() {
  test('default preparation shares the injected decode and releases intermediate PCM', () async {
    final decoder = _Decoder();
    final analysis = defaultPreparationAudio(decoder: decoder);
    const source = AudioSource.file('/music.wav');
    final grid = await analysis.beats.detect(source, fps: 30, totalFrames: 30);
    final bands = await analysis.bands.analyze(source, fps: 30, totalFrames: 30);
    expect(decoder.calls, 1);
    analysis.dispose();
    expect(await analysis.beats.detect(source, fps: 30, totalFrames: 30), same(grid));
    expect(await analysis.bands.analyze(source, fps: 30, totalFrames: 30), same(bands));
    await expectLater(analysis.beats.detect(source, fps: 24, totalFrames: 24), throwsStateError);
    analysis.dispose();
  });
}
