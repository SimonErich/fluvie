import 'dart:typed_data';

/// Peak-picks onset frames from a spectral-[flux] curve with an adaptive
/// threshold — the highest-uncertainty step, so the algorithm is kept simple,
/// pure, and fully test-pinned.
///
/// A frame is reported as an onset when all three hold:
///
/// * it is a strict local maximum within `± [neighborhood]` frames (a real
///   peak, not a shoulder),
/// * its flux exceeds an **adaptive threshold** — the local mean over
///   `± [windowSize]` frames times [thresholdRatio], plus a small absolute
///   [floorDelta] so a flat, near-silent curve never crosses its own mean, and
/// * it is at least [minGap] frames after the previous accepted onset (one beat
///   is not double-counted across the 50%-overlapped frames).
///
/// Returns the accepted frame indices into [flux] in ascending order. Pure and
/// deterministic: the same [flux] always yields the same onsets, which is what
/// makes the beat grid reproducible across runs and machines.
List<int> detectOnsets(
  Float64List flux, {
  int windowSize = 8,
  int neighborhood = 3,
  double thresholdRatio = 1.7,
  double floorDelta = 0.04,
  int minGap = 4,
}) {
  final onsets = <int>[];
  var lastOnset = -minGap - 1;
  for (var i = 0; i < flux.length; i++) {
    final value = flux[i];
    if (value < floorDelta) continue;
    if (!_isLocalMax(flux, i, neighborhood)) continue;
    final threshold = _localMean(flux, i, windowSize) * thresholdRatio + floorDelta;
    if (value < threshold) continue;
    if (i - lastOnset < minGap) {
      // Keep the stronger of two peaks inside one gap (the later one wins only
      // when it is clearly louder), so a single click is one onset.
      if (onsets.isNotEmpty && value > flux[onsets.last]) {
        onsets[onsets.length - 1] = i;
        lastOnset = i;
      }
      continue;
    }
    onsets.add(i);
    lastOnset = i;
  }
  return onsets;
}

/// Whether [flux] at [index] is a strict maximum over `± [radius]` neighbors.
bool _isLocalMax(Float64List flux, int index, int radius) {
  final lo = (index - radius).clamp(0, flux.length - 1);
  final hi = (index + radius).clamp(0, flux.length - 1);
  for (var j = lo; j <= hi; j++) {
    if (j != index && flux[j] >= flux[index]) return false;
  }
  return true;
}

/// The mean of [flux] over `± [radius]` frames around [index] (clamped to the
/// curve's bounds).
double _localMean(Float64List flux, int index, int radius) {
  final lo = (index - radius).clamp(0, flux.length - 1);
  final hi = (index + radius).clamp(0, flux.length - 1);
  var sum = 0.0;
  for (var j = lo; j <= hi; j++) {
    sum += flux[j];
  }
  return sum / (hi - lo + 1);
}

/// Maps onset frame indices ([onsetFrames] into a flux curve) to absolute video
/// frames at [fps], given the analysis [hopSize] and [sampleRate].
///
/// Each onset frame `h` sits at sample `h · hopSize`, i.e. `h · hopSize /
/// sampleRate` seconds, i.e. `that · fps` video frames (rounded). The result is
/// the beat grid's frame space — the same absolute frames `Trigger.beat` and the
/// reactive scope query. Order and count are preserved.
List<int> onsetFramesAt(
  List<int> onsetFrames, {
  required int hopSize,
  required int sampleRate,
  required int fps,
}) => [
  for (final hop in onsetFrames) (hop * hopSize / sampleRate * fps).round(),
];
