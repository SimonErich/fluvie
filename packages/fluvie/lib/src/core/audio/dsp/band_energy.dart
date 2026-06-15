import 'dart:typed_data';

/// The summed magnitude energy of one analysis frame split across the three
/// frequency bands: `bass`, `mid`, and `treble`, in the same order as the
/// `AudioBand` enum.
typedef BandEnergies = ({double bass, double mid, double treble});

/// The upper frequency (Hz) of the bass band; bins below it are bass.
const double _bassMaxHz = 250;

/// The upper frequency (Hz) of the mid band; bins from [_bassMaxHz] up to this
/// are mid, and everything above is treble.
const double _midMaxHz = 4000;

/// Sums the single-sided [magnitudes] of one FFT frame into the three
/// `AudioBand` ranges.
///
/// Each non-DC bin `b` maps to the frequency `b · sampleRate / windowSize` and
/// is added to the band that frequency falls in: bass below 250 Hz, mid up to
/// 4 kHz, treble above. The DC bin (0) is excluded — it carries no musical
/// pitch — so bins `1 .. windowSize/2` partition exactly across the three sums.
/// Pure and deterministic: the same [magnitudes] always sum the same way, which
/// is what makes the band table reproducible across runs and machines.
BandEnergies bandEnergies(
  Float64List magnitudes, {
  required int sampleRate,
  required int windowSize,
}) {
  final binHz = sampleRate / windowSize;
  var bass = 0.0;
  var mid = 0.0;
  var treble = 0.0;
  for (var bin = 1; bin < magnitudes.length; bin++) {
    final hz = bin * binHz;
    final magnitude = magnitudes[bin];
    if (hz < _bassMaxHz) {
      bass += magnitude;
    } else if (hz < _midMaxHz) {
      mid += magnitude;
    } else {
      treble += magnitude;
    }
  }
  return (bass: bass, mid: mid, treble: treble);
}
