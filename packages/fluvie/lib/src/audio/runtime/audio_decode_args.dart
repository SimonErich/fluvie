import 'package:fluvie/src/audio/encoding/audio_filter_graph.dart';

/// The validated FFmpeg argument array that decodes the sandbox-relative audio
/// file [name] to raw 32-bit-float mono PCM at 44.1 kHz, piped to stdout.
///
/// Pure and deterministic: the beat detector and frequency analyzer spawn
/// FFmpeg with exactly this array, read the `f32le` stream, and run the in-house
/// DSP on it. The name is gated by [validateAudioName] so it can never escape
/// the sandbox or be parsed as a flag; the mono/44100 shape is fixed so the
/// analysis is reproducible across machines.
List<String> audioDecodeArgs(String name, {Duration? start, Duration? duration}) {
  if (start != null && start.isNegative || duration != null && duration <= Duration.zero) {
    throw ArgumentError('Audio decoding requires a non-negative start and positive duration.');
  }
  return [
    if (start != null && start > Duration.zero) ...[
      '-ss',
      (start.inMicroseconds / 1000000).toStringAsFixed(6),
    ],
    '-i',
    validateAudioName(name),
    if (duration != null) ...['-t', (duration.inMicroseconds / 1000000).toStringAsFixed(6)],
    '-f',
    'f32le',
    '-ac',
    '1',
    '-ar',
    '44100',
    '-',
  ];
}
