import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fluvie/rendering.dart' show PcmAudio, ResolvedAudioTrack, audioVolumeAt;

/// A decoded source and its resolved export mix settings, with the ephemeral
/// monitoring multiplier already applied. Document/export state is untouched.
final class AudioPreviewTrack {
  /// Creates one preview input.
  const AudioPreviewTrack({required this.audio, required this.track, this.monitorGain = 1});

  /// Cached mono source PCM.
  final PcmAudio audio;

  /// Same trim/delay/rate/fades/envelope used by the export.
  final ResolvedAudioTrack track;

  /// Solo/mute audition multiplier, never serialized.
  final double monitorGain;
}

/// Renders a bounded preview chunk to 16-bit mono WAV bytes. The caller plays
/// it through the platform output seam and cancels/restarts on seek or a mix
/// change. Mixing is pure and deterministic; it opens no audio device.
Uint8List renderAudioPreviewWav({
  required List<AudioPreviewTrack> tracks,
  required double startSeconds,
  required double durationSeconds,
  int sampleRate = 48000,
  double masterGain = 1,
}) {
  if (!startSeconds.isFinite ||
      startSeconds < 0 ||
      !durationSeconds.isFinite ||
      durationSeconds <= 0 ||
      durationSeconds > 30 ||
      sampleRate < 1 ||
      sampleRate > 192000) {
    throw ArgumentError('Preview requires a finite start and a bounded 0..30 second chunk');
  }
  final count = (durationSeconds * sampleRate).round();
  final samples = Float64List(count);
  for (final input in tracks) {
    final track = input.track;
    final pcm = input.audio;
    if (input.monitorGain == 0 || track.volume == 0 || pcm.samples.isEmpty) continue;
    final trimStart = track.trimStartSeconds ?? 0;
    final trimEnd = math.min(
      track.trimEndSeconds ?? (pcm.samples.length / pcm.sampleRate),
      pcm.samples.length / pcm.sampleRate,
    );
    final span = trimEnd - trimStart;
    if (span <= 0 || track.tempo <= 0) continue;
    for (var i = 0; i < count; i++) {
      final absolute = startSeconds + i / sampleRate;
      final local = absolute - track.delayMs / 1000;
      if (local < 0 || (track.endSeconds != null && absolute >= track.endSeconds!)) continue;
      if (track.timeMap != null && local >= track.timeMap!.durationSeconds) continue;
      var source = track.timeMap?.sourceSecondsAt(local) ?? local * track.tempo;
      if (track.loop) {
        source %= span;
      } else if (source >= span) {
        continue;
      }
      final index = (trimStart + source) * pcm.sampleRate;
      final from = index.floor().clamp(0, pcm.samples.length - 1);
      final to = (from + 1).clamp(0, pcm.samples.length - 1);
      final value =
          pcm.samples[from] + (pcm.samples[to] - pcm.samples[from]) * (index - index.floor());
      var gain =
          track.volume *
          input.monitorGain *
          masterGain *
          audioVolumeAt(track.volumeEnvelope, local);
      if (track.fadeInSeconds case final double fade when fade > 0) {
        gain *= (local / fade).clamp(0.0, 1.0);
      }
      if (track.fadeOutSeconds case final double fade when fade > 0) {
        gain *= (1 - (absolute - track.fadeOutStartSeconds) / fade).clamp(0.0, 1.0);
      }
      samples[i] += value * gain;
    }
  }
  final bytes = Uint8List(44 + count * 2);
  final data = ByteData.sublistView(bytes);
  void text(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes[offset + i] = value.codeUnitAt(i);
    }
  }

  text(0, 'RIFF');
  data.setUint32(4, 36 + count * 2, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  data
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  text(36, 'data');
  data.setUint32(40, count * 2, Endian.little);
  for (var i = 0; i < count; i++) {
    data.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  return bytes;
}
