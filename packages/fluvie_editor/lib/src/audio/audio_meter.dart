import 'dart:math' as math;

import 'package:fluvie/rendering.dart' show ResolvedAudioTrack, WaveformEnvelope, audioVolumeAt;

/// Converts dB to linear amplitude (negative infinity is silence).
double decibelsToGain(double decibels) =>
    decibels == double.negativeInfinity ? 0 : math.pow(10, decibels / 20).toDouble();

/// Converts linear amplitude to dB; zero is negative infinity.
double gainToDecibels(double gain) =>
    gain <= 0 ? double.negativeInfinity : 20 * math.log(gain) / math.ln10;

/// A deterministic waveform-derived level estimate. Cached envelopes omit
/// sample phase: combined peak is a conservative ceiling and RMS assumes
/// uncorrelated sources; neither is claimed to be a live device measurement.
final class AudioMeterLevel {
  /// Linear peak and RMS amplitudes (may exceed one to indicate clipping).
  const AudioMeterLevel({this.peak = 0, this.rms = 0});

  /// Combines cached track estimates in declaration order.
  factory AudioMeterLevel.mix(Iterable<AudioMeterLevel> levels) {
    var peak = 0.0;
    var power = 0.0;
    for (final level in levels) {
      peak += level.peak;
      power += level.rms * level.rms;
    }
    return AudioMeterLevel(peak: peak, rms: math.sqrt(power));
  }

  /// Peak amplitude, before clipping.
  final double peak;

  /// RMS amplitude, before clipping.
  final double rms;

  /// Whether the signal estimate exceeds full scale.
  bool get clipping => peak > 1;
}

/// Reads one resolved track at absolute composition time from cached waveform
/// data, applying trim, looping, rate, gain, fades, automation and monitor gain.
AudioMeterLevel meterTrack({
  required ResolvedAudioTrack track,
  required WaveformEnvelope envelope,
  required double seconds,
  double monitorGain = 1,
}) {
  final local = seconds - track.delayMs / 1000;
  if ((track.endSeconds != null && seconds >= track.endSeconds!) ||
      local < 0 ||
      envelope.buckets.isEmpty ||
      envelope.durationSeconds <= 0) {
    return const AudioMeterLevel();
  }
  final start = track.trimStartSeconds ?? 0;
  final end = math.min(track.trimEndSeconds ?? envelope.durationSeconds, envelope.durationSeconds);
  final span = end - start;
  if (track.timeMap != null && local >= track.timeMap!.durationSeconds) {
    return const AudioMeterLevel();
  }
  if (span <= 0) return const AudioMeterLevel();
  var source = track.timeMap?.sourceSecondsAt(local) ?? local * track.tempo;
  if (track.loop) {
    source %= span;
  } else if (source >= span) {
    return const AudioMeterLevel();
  }
  source += start;
  final index = (source / envelope.durationSeconds * envelope.buckets.length).floor().clamp(
    0,
    envelope.buckets.length - 1,
  );
  final bucket = envelope.buckets[index];
  var gain = track.volume * monitorGain * audioVolumeAt(track.volumeEnvelope, local);
  final fadeIn = track.fadeInSeconds;
  if (fadeIn != null && fadeIn > 0) gain *= (local / fadeIn).clamp(0.0, 1.0);
  final fadeOut = track.fadeOutSeconds;
  if (fadeOut != null && fadeOut > 0) {
    gain *= (1 - (seconds - track.fadeOutStartSeconds) / fadeOut).clamp(0.0, 1.0);
  }
  return AudioMeterLevel(peak: bucket.peak * gain.abs(), rms: bucket.rms * gain.abs());
}
