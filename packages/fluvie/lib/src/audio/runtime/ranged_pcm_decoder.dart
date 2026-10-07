import 'package:fluvie/src/audio/runtime/pcm_decoder.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/dsp/wav_reader.dart';

/// Optional bounded-source decoding capability for native audio analysis.
/// The returned samples begin at the requested start; a shorter source may return fewer
/// samples. Callers retain the source-time offset when using a nonzero start.
abstract interface class RangedPcmDecoder implements PcmDecoder {
  /// Decodes a non-negative [start] and positive [duration] without decoding
  /// the entire source. Implementations must validate the interval before IO.
  Future<PcmAudio> decodeRange(
    AudioSource source, {
    required Duration start,
    required Duration duration,
  });
}
