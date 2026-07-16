import 'dart:io';

import 'package:fluvie/rendering.dart';
// The reactive pre-pass wiring is render infrastructure under `src/`: the WAV
// reader and the PcmDecoder seam are off the authoring surface a lesson imports.
import 'package:fluvie/src/audio/runtime/pcm_decoder.dart';
import 'package:fluvie/src/audio/runtime/spectral_beat_detection_service.dart';
import 'package:fluvie/src/audio/runtime/spectral_frequency_analyzer.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/dsp/wav_reader.dart';

/// A [PcmDecoder] that reads a committed WAV file straight off disk with the
/// in-house [readPcmWav] reader — no ffmpeg, so the reactive analysis runs in
/// the gate.
///
/// The `MediaRepository` materializes each declared `AudioSource` to a temp file
/// and hands the services a [FileAudioSource] pointing at it, so this decoder
/// only ever sees a file path. It rejects anything that is not a file source,
/// because the example commits WAV fixtures precisely so the gate path never
/// reaches ffmpeg (decision D-Lesson / D-DSP).
final class WavFilePcmDecoder implements PcmDecoder {
  /// Creates the offline WAV decoder.
  const WavFilePcmDecoder();

  @override
  Future<PcmAudio> decode(AudioSource source) async {
    final path = switch (source) {
      FileAudioSource(:final path) => path,
      _ => throw StateError(
        'The example reactive pre-pass decodes only committed WAV files; the '
        'repository materializes every AudioSource to a file before analysis, '
        'so an unexpected source ($source) would mean a non-WAV fixture or a '
        'live ffmpeg decode breaking offline determinism.',
      ),
    };
    return readPcmWav(await File(path).readAsBytes());
  }
}

/// The real spectral beat detector over the in-house WAV decoder — the gate
/// default, so the beat grid `Trigger.beat` reads is computed with no ffmpeg.
BeatDetectionService offlineBeatDetector() =>
    SpectralBeatDetectionService(decoder: const WavFilePcmDecoder());

/// The real spectral analyzer over the in-house WAV decoder, the band-table
/// counterpart of [offlineBeatDetector].
FrequencyAnalyzer offlineFrequencyAnalyzer() =>
    SpectralFrequencyAnalyzer(decoder: const WavFilePcmDecoder());
