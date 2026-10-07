import 'package:fluvie/src/audio/runtime/ffmpeg_pcm_decoder.dart';
import 'package:fluvie/src/audio/runtime/pcm_decoder.dart';
import 'package:fluvie/src/audio/runtime/shared_pcm_decoder.dart';
import 'package:fluvie/src/audio/runtime/spectral_beat_detection_service.dart';
import 'package:fluvie/src/audio/runtime/spectral_frequency_analyzer.dart';
import 'package:fluvie/src/core/contracts/beat_detection_service.dart';
import 'package:fluvie/src/core/contracts/frequency_analyzer.dart';

/// Native analysis services share bounded PCM during one preparation.
/// Dispose after the derived beat grids and band tables have been prepared.
({BeatDetectionService beats, FrequencyAnalyzer bands, void Function() dispose})
defaultPreparationAudio({
  Future<void>? whenCancelled,
  PcmDecoder? decoder,
}) {
  final shared = SharedPcmDecoder(
    decoder ?? FfmpegPcmDecoder(whenCancelled: whenCancelled),
    whenCancelled: whenCancelled,
  );
  return (
    beats: SpectralBeatDetectionService(decoder: shared),
    bands: SpectralFrequencyAnalyzer(decoder: shared),
    dispose: shared.dispose,
  );
}
