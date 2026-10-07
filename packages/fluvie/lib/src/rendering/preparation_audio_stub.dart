import 'package:fluvie/src/audio/runtime/pcm_decoder.dart';
import 'package:fluvie/src/core/contracts/beat_detection_service.dart';
import 'package:fluvie/src/core/contracts/frequency_analyzer.dart';
import 'package:fluvie/src/core/errors/fluvie_capability_exception.dart';

/// Browser hosts inject their audio analysis services.
({BeatDetectionService beats, FrequencyAnalyzer bands, void Function() dispose})
defaultPreparationAudio({
  Future<void>? whenCancelled,
  PcmDecoder? decoder,
}) => throw FluvieCapabilityException(
  capability: 'Reactive audio analysis',
  host: 'this browser preview',
  remedy:
      'Supply an analysis-capable MediaResolver, beatDetector and analyzer, or render through the native host.',
);
