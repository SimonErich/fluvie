import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie/src/audio/runtime/ffmpeg_audio_decoder.dart';
import 'package:fluvie/src/audio/runtime/pcm_decoder.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/dsp/wav_reader.dart';

/// The ffmpeg-backed [PcmDecoder]: the live, per-machine path that decodes any
/// declared audio file to mono `f32le` PCM at 44.1 kHz for the in-house DSP.
///
/// This is the only `// coverage:ignore` glue in the beat pipeline — it spawns
/// ffmpeg (via the pure, unit-tested `audioDecodeArgs` inside
/// [FfmpegAudioDecoder]), so it cannot run in the gate and is exercised behind
/// the `ffmpeg` test tag; its argument array is built and validated purely.
/// The gate-default analysis tests inject a WAV-reader decoder instead, keeping
/// detection fully gate-runnable. The decoded samples are reproducible per
/// machine; the bytes themselves are the documented per-machine exception
/// (ffmpeg builds differ), but the analysis derived from them is stable.
///
/// It expects the source already materialized to a local file path (the audio
/// resolver does this before frame 0); only [FileAudioSource] reaches the live
/// decode, so an unmaterialized asset/network source is a clear error rather
/// than a silent re-fetch.
final class FfmpegPcmDecoder implements PcmDecoder {
  /// Creates a decoder over the ffmpeg [decoder] (defaults to `ffmpeg` on PATH).
  const FfmpegPcmDecoder({this.decoder = const FfmpegAudioDecoder()});

  /// The ffmpeg spawn glue this decoder reads f32le PCM through.
  final FfmpegAudioDecoder decoder;

  // coverage:ignore-start process glue it spawns the real ffmpeg binary via the decoder so it runs only under the ffmpeg tagged suite never the unit gate
  @override
  Future<PcmAudio> decode(AudioSource source) async {
    final path = switch (source) {
      FileAudioSource(:final path) => path,
      _ => throw ArgumentError.value(
        source,
        'source',
        'FfmpegPcmDecoder needs a materialized file path; the audio resolver '
            'materializes every source to a FileAudioSource before analysis',
      ),
    };
    final file = File(path);
    final samples = await decoder.decode(
      file.uri.pathSegments.last,
      workingDirectory: file.parent.path,
    );
    return (samples: _toFloat64(samples), sampleRate: 44100);
  }

  /// Widens the decoded `f32le` samples to the [PcmAudio] `Float64List` the DSP
  /// reads.
  static Float64List _toFloat64(Float32List samples) {
    final out = Float64List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      out[i] = samples[i];
    }
    return out;
  }

  // coverage:ignore-end
}
