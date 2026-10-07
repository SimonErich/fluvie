// #docregion desktop-analysis-limits
import 'package:fluvie/rendering.dart';

/// A custom host shares this cancellation signal with its composition session.
({BeatDetectionService beats, FrequencyAnalyzer bands}) boundedDesktopAnalysis(
  RenderCancellation cancellation,
) {
  final decoder = FfmpegPcmDecoder(
    decoder: const FfmpegAudioDecoder(
      maxSamples: 32000000,
      timeout: Duration(minutes: 4),
    ),
    whenCancelled: cancellation.whenCancelled,
  );
  return (
    beats: SpectralBeatDetectionService(decoder: decoder),
    bands: SpectralFrequencyAnalyzer(decoder: decoder),
  );
}
// #enddocregion desktop-analysis-limits
