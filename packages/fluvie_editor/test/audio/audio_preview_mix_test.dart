import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_editor/src/audio/audio_preview_mix.dart';

void main() {
  test('preview samples match gain, delayed automation and solo at seek time', () {
    final pcm = (samples: Float64List.fromList(List<double>.filled(3000, 0.5)), sampleRate: 1000);
    final track = AudioPreviewTrack(
      audio: pcm,
      track: const ResolvedAudioTrack(
        source: 'a',
        delayMs: 1000,
        volume: 0.5,
        volumeEnvelope: [AudioVolumePoint(0, 1), AudioVolumePoint(1, 0)],
      ),
    );
    final result = readPcmWav(
      renderAudioPreviewWav(
        tracks: [track],
        startSeconds: 0.5,
        durationSeconds: 2,
        sampleRate: 1000,
      ),
    );
    expect(result.samples[0], 0);
    expect(result.samples[500], closeTo(0.25, 0.0001));
    expect(result.samples[1000], closeTo(0.125, 0.0001));
    expect(result.samples[1500], 0);
    final soloed = AudioPreviewTrack(audio: pcm, track: track.track, monitorGain: 0);
    final silence = readPcmWav(
      renderAudioPreviewWav(
        tracks: [soloed],
        startSeconds: 1,
        durationSeconds: 1,
        sampleRate: 1000,
      ),
    );
    expect(silence.samples, everyElement(0));
  });
  test('preview chunk bounds reject unbounded allocation', () {
    expect(
      () => renderAudioPreviewWav(tracks: [], startSeconds: 0, durationSeconds: 31),
      throwsArgumentError,
    );
    expect(
      () => renderAudioPreviewWav(tracks: [], startSeconds: double.nan, durationSeconds: 1),
      throwsArgumentError,
    );
  });
}
