import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie/src/audio/runtime/ffmpeg_audio_decoder.dart';
import 'package:fluvie/src/audio/runtime/pcm_decoder.dart';
import 'package:fluvie/src/audio/runtime/ranged_pcm_decoder.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/dsp/wav_reader.dart';

/// The ffmpeg-backed [PcmDecoder]: the live, per-machine path that decodes any
/// declared audio file to mono `f32le` PCM at 44.1 kHz for the in-house DSP.
///
/// [FfmpegAudioDecoder] bounds PCM and diagnostics and stops its owned process
/// on timeout or cancellation. Tests can inject a WAV-reader decoder instead.
/// PCM bytes can vary between FFmpeg builds; subsequent analysis is stable.
///
/// It expects the source already materialized to a local file path (the audio
/// resolver does this before frame 0); only [FileAudioSource] reaches the live
/// decode, so an unmaterialized asset/network source is a clear error rather
/// than a silent re-fetch.
final class FfmpegPcmDecoder implements RangedPcmDecoder {
  /// Creates a decoder over the ffmpeg [decoder] (defaults to `ffmpeg` on PATH).
  const FfmpegPcmDecoder({this.decoder = const FfmpegAudioDecoder(), this.whenCancelled});

  /// The ffmpeg spawn glue this decoder reads f32le PCM through.
  final FfmpegAudioDecoder decoder;

  /// Cancellation shared by the preparation owner with the decoder process.
  final Future<void>? whenCancelled;

  @override
  Future<PcmAudio> decode(AudioSource source) async {
    return _decode(source);
  }

  @override
  Future<PcmAudio> decodeRange(
    AudioSource source, {
    required Duration start,
    required Duration duration,
  }) {
    if (start.isNegative || duration <= Duration.zero) {
      throw ArgumentError('Invalid audio source interval.');
    }
    return _decode(source, start: start, duration: duration);
  }

  Future<PcmAudio> _decode(AudioSource source, {Duration? start, Duration? duration}) async {
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
      whenCancelled: whenCancelled,
      start: start,
      duration: duration,
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
}
