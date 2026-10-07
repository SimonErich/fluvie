import 'dart:typed_data';

import 'package:fluvie/src/audio/runtime/pcm_decoder.dart';
import 'package:fluvie/src/audio/runtime/ranged_pcm_decoder.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/dsp/wav_reader.dart';

/// Decodes the source prefix queried by a composition plus 250 ms of FFT/onset
/// lookahead. Legacy decoders retain their full-source behavior. Both analysis
/// consumers use the identical interval so a shared decoder coalesces their IO.
Future<PcmAudio> decodeAnalysisPcm(
  PcmDecoder decoder,
  AudioSource source, {
  required int fps,
  required int totalFrames,
  Duration start = Duration.zero,
}) async {
  if (fps < 1 || totalFrames < 1 || start.isNegative) {
    throw ArgumentError('Audio analysis requires a positive timeline.');
  }
  final duration = Duration(microseconds: (totalFrames * 1000000 / fps).ceil() + 250000);
  if (decoder is RangedPcmDecoder) {
    return decoder.decodeRange(source, start: start, duration: duration);
  }
  final pcm = await decoder.decode(source);
  if (start == Duration.zero) return pcm;
  final first = (start.inMicroseconds * pcm.sampleRate / 1000000).round().clamp(
    0,
    pcm.samples.length,
  );
  final last = (first + duration.inMicroseconds * pcm.sampleRate / 1000000).ceil().clamp(
    first,
    pcm.samples.length,
  );
  return (
    samples: Float64List.fromList(pcm.samples.sublist(first, last)),
    sampleRate: pcm.sampleRate,
  );
}
