@Tags(['ffmpeg'])
library;

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:slides/editor/audio_preview_platform.dart';

void main() {
  test('native decodes and plays a generated WAV through the platform output', () async {
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
        durationSeconds: .1,
        sampleRate: 8000,
      );
      final audio = await platform.decode(AudioSource.memory(wav, debugLabel: 'probe.wav'));
      expect(audio.sampleRate, 22050);
      expect(audio.samples.length, closeTo(2205, 1));
      await platform.play(wav);
      await platform.stop();
      final pending = platform.play(wav);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await platform.stop();
      await pending.timeout(const Duration(seconds: 5));
    } finally {
      await platform.dispose();
    }
  });
}
