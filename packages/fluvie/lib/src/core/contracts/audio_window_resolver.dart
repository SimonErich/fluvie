import 'package:fluvie/src/core/audio/audio_analysis_window.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/contracts/beat_detection_service.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/core/contracts/frequency_analyzer.dart';

/// Optional resolver capability for track-aware trim, placement, and loops.
/// Existing MediaResolver implementations retain their source-only contract.
abstract interface class AudioWindowResolver {
  /// Prepares each unique window; lookups below perform no IO.
  Future<void> preResolveAudioWindows(
    Iterable<AudioAnalysisWindow> windows, {
    required BeatDetectionService beatDetector,
    required FrequencyAnalyzer analyzer,
  });

  /// Prepared beat positions on the absolute composition clock.
  BeatGrid beatGridForWindow(AudioAnalysisWindow window);

  /// Prepared energies, with silence outside the audible window.
  BandTable bandTableForWindow(AudioAnalysisWindow window);
}
