import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/band_table.dart';

/// Analyses one audio track into a per-frame [BandTable] driving
/// spectrum-reactive animations.
///
/// The real implementation decodes the track to PCM once before frame 0, runs
/// the in-house FFT, sums the bass / mid / treble bins per analysis frame,
/// resamples those per-hop sums onto one value per video frame, normalizes each
/// band into `[0, 1]`, and content-hash caches the table as JSON. Analysis is
/// async, so it runs entirely in the pre-resolve pass — the frame loop only ever
/// reads the resulting immutable table through `BandTable.energyAt`.
///
/// The spectral implementation is the one that ships, and the
/// analyse-twice→identical-table property is the determinism proof. `BandTable`
/// is the result; the real `SpectralFrequencyAnalyzer` is named in prose because
/// it lives above `core`.
// One member by design: the contract is the *type*, injected via a provider so
// the reactive scope reads a real band table at render and a fake in tests.
// ignore: one_member_abstracts
abstract interface class FrequencyAnalyzer {
  /// Analyses [source] into a [BandTable] over a video of [totalFrames] frames
  /// at [fps].
  ///
  /// Runs in the pre-resolve pass before the frame loop. Throws a
  /// `FluvieRenderException` when the source cannot be decoded.
  Future<BandTable> analyze(AudioSource source, {required int fps, required int totalFrames});
}
