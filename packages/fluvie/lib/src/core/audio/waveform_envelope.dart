import 'dart:math' as math;

import 'package:fluvie/src/core/audio/dsp/wav_reader.dart';
import 'package:meta/meta.dart';

/// One column of a waveform drawing: the extremes and the loudness of the
/// samples it covers.
///
/// Both are kept because they answer different questions. [min] and [max] are
/// what a waveform's outline is drawn from — they show transients, and losing
/// one would make the drawing understate a click. [rms] is what the eye reads
/// as loudness, and for anything but a square wave it sits well below the peak.
@immutable
final class WaveformBucket {
  /// Creates a bucket over an already-reduced span.
  const WaveformBucket({required this.min, required this.max, required this.rms});

  /// A bucket covering no samples at all.
  static const WaveformBucket silent = WaveformBucket(min: 0, max: 0, rms: 0);

  /// The most negative sample in the span, in `[-1, 1]`.
  final double min;

  /// The most positive sample in the span, in `[-1, 1]`.
  final double max;

  /// The root-mean-square of the span, in `[0, 1]` — perceived level.
  final double rms;

  /// The larger absolute extreme, whichever side of zero it fell on.
  double get peak => math.max(max.abs(), min.abs());

  @override
  bool operator ==(Object other) =>
      other is WaveformBucket && other.min == min && other.max == max && other.rms == rms;

  @override
  int get hashCode => Object.hash(WaveformBucket, min, max, rms);

  @override
  String toString() => 'WaveformBucket(min: $min, max: $max, rms: $rms)';
}

/// A decoded track reduced to evenly spaced [buckets] an editor can draw.
///
/// Pure data: the reduction happens once, off the frame path, and a drawing
/// reads it synchronously however many times it repaints.
@immutable
final class WaveformEnvelope {
  /// Creates an envelope over already-reduced [buckets].
  const WaveformEnvelope({
    required this.buckets,
    required this.sampleRate,
    required this.durationSeconds,
  });

  /// The columns, in time order and evenly spaced across [durationSeconds].
  final List<WaveformBucket> buckets;

  /// The sample rate the source decoded at.
  final int sampleRate;

  /// How long the reduced audio runs, in seconds.
  final double durationSeconds;

  @override
  String toString() =>
      'WaveformEnvelope(${buckets.length} buckets, ${durationSeconds}s @ ${sampleRate}Hz)';
}

/// Reduces decoded [audio] to [buckets] evenly spaced columns.
///
/// A pure time-domain reduction: each bucket reports the extremes and the RMS
/// of the samples it covers. It deliberately does **not** build on `BandTable`,
/// which peak-normalises each frequency band against that band's own maximum
/// and is therefore not proportional to signal level — summing its bands would
/// draw a waveform that lies about loudness.
///
/// Bucket boundaries are `k * samples ~/ buckets`, which makes the reduction
/// **nest exactly** when the bucket count doubles: bucket `j` at one zoom level
/// covers precisely buckets `2j` and `2j + 1` at the next, so a peak visible at
/// one width can never vanish at another. That is what lets an editor redraw
/// the same waveform at any width without lying about the audio.
///
/// Empty audio yields an empty envelope rather than throwing — a clip with no
/// sound is a normal thing to draw. A [buckets] count below one is an
/// [ArgumentError]: there is no honest reduction to zero columns.
WaveformEnvelope reduceToWaveform(PcmAudio audio, {required int buckets}) {
  if (buckets < 1) {
    throw ArgumentError.value(buckets, 'buckets', 'must be at least one column');
  }
  final samples = audio.samples;
  final rate = audio.sampleRate;
  if (samples.isEmpty) {
    return WaveformEnvelope(
      buckets: const [],
      sampleRate: rate,
      durationSeconds: 0,
    );
  }
  final columns = <WaveformBucket>[];
  for (var k = 0; k < buckets; k++) {
    var start = k * samples.length ~/ buckets;
    var end = (k + 1) * samples.length ~/ buckets;
    if (end <= start) {
      // More columns than samples: hold the nearest sample rather than leaving
      // a hole in the drawing.
      start = math.min(start, samples.length - 1);
      end = start + 1;
    }
    columns.add(_reduceSpan(samples, start, end));
  }
  return WaveformEnvelope(
    buckets: List.unmodifiable(columns),
    sampleRate: rate,
    durationSeconds: rate <= 0 ? 0 : samples.length / rate,
  );
}

/// The extremes and RMS of `samples[start..end)`.
WaveformBucket _reduceSpan(List<double> samples, int start, int end) {
  var low = samples[start];
  var high = samples[start];
  var sumSquares = 0.0;
  for (var i = start; i < end; i++) {
    final value = samples[i];
    if (value < low) low = value;
    if (value > high) high = value;
    sumSquares += value * value;
  }
  return WaveformBucket(
    min: low,
    max: high,
    rms: math.sqrt(sumSquares / (end - start)),
  );
}
