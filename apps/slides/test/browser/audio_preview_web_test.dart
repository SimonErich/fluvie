@TestOn('browser')
@Tags(['browser'])
library;

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:slides/editor/audio_preview_platform.dart';

void main() {
  test('Web Audio decodes, plays and cancels a mixed mono WAV', () async {
    final platform = createAudioPreviewPlatform();
    try {
      final wav = renderAudioPreviewWav(
        tracks: [
          AudioPreviewTrack(
            audio: (
              samples: Float64List.fromList(List.generate(800, (i) => i.isEven ? 0.2 : -0.2)),
              sampleRate: 8000,
            ),
            track: const ResolvedAudioTrack(source: 'probe'),
          ),
        ],
        startSeconds: 0,
        durationSeconds: 0.1,
        sampleRate: 8000,
      );
      final audio = await platform.decode(AudioSource.memory(wav));
      expect(audio.samples.length / audio.sampleRate, closeTo(0.1, 0.001));
      platform.unlock();
      await platform.play(wav).timeout(const Duration(seconds: 5));
      final output = platform.play(wav);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await platform.stop();
      await output.timeout(const Duration(seconds: 5));
    } finally {
      await platform.dispose();
    }
  });
}
