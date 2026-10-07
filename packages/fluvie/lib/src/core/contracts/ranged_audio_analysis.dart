import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/contracts/beat_detection_service.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/core/contracts/frequency_analyzer.dart';

/// Optional beat analysis starting at a source trim. Returned frames are
/// relative to the requested source start, before placement on the composition clock.
abstract interface class RangedBeatDetectionService implements BeatDetectionService {
  /// Detects only the requested source interval, with internal DSP lookahead.
  Future<BeatGrid> detectRange(
    AudioSource source, {
    required Duration start,
    required int fps,
    required int totalFrames,
  });
}

/// Bounded band energies and the actual decoded source duration, before
/// placement. The duration preserves fractional-frame loop periods at EOF.
typedef RangedBandAnalysis = ({BandTable table, Duration duration});

/// Optional frequency analysis starting at a source trim. The returned table
/// may be shorter than requested when the source ends, allowing honest silence.
abstract interface class RangedFrequencyAnalyzer implements FrequencyAnalyzer {
  /// Analyzes only the requested source interval, with internal DSP lookahead.
  Future<RangedBandAnalysis> analyzeRange(
    AudioSource source, {
    required Duration start,
    required int fps,
    required int totalFrames,
  });
}
