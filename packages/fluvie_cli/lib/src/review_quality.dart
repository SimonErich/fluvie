import 'package:fluvie_cli/src/process_runner.dart';

/// Stable finding codes that callers can explicitly allow for artistic intent.
const reviewQualityCodes = {
  'text_overflow',
  'text_too_brief',
  'font_not_bundled',
  'audio_silence',
  'audio_peak',
};

/// Returns a quality report retaining both active and intentionally allowed
/// findings. [strict] fails on active warnings or unavailable measurements;
/// exports without an audio stream are explicitly inapplicable. Normal reviews
/// remain advisory.
Map<String, Object?> evaluateReviewQuality(
  Map<String, Object?> quality, {
  Set<String> allowed = const {},
  bool strict = false,
}) {
  if (!reviewQualityCodes.containsAll(allowed)) {
    throw ArgumentError('Unknown quality finding code.');
  }
  final findings = [
    for (final finding in ((quality['findings'] as List?) ?? const []).cast<Map<String, Object?>>())
      {
        ...finding,
        'allowed': allowed.contains(finding['code']),
        if (allowed.contains(finding['code']))
          'allowReason': 'Explicitly allowed by the review caller.',
      },
  ];
  final audio = quality['audio'] as Map<String, Object?>?;
  final complete = audio == null || audio['checked'] == true || audio['applicable'] == false;
  return {
    ...quality,
    'checksComplete': complete,
    'findings': findings,
    'strict': strict,
    'ok': !strict || complete && findings.every((finding) => finding['allowed'] == true),
  };
}

/// Measures the encoded audio through the resolved FFmpeg pair. This scans the
/// full mix. Near-full-scale peaks indicate clipping risk, not proven distortion;
/// silence below -50 dB lasting at least 500 ms may be intentional.
Future<Map<String, Object?>> inspectOutputAudio({
  required ProcessRunner runner,
  required String ffmpeg,
  required String path,
  required int fps,
}) async {
  final result = await runner.run(ffmpeg, [
    '-hide_banner',
    '-nostats',
    '-i',
    path,
    '-vn',
    '-af',
    'astats=metadata=0:reset=0,silencedetect=noise=-50dB:d=0.5',
    '-f',
    'null',
    '-',
  ]);
  if (result.exitCode != 0) {
    return {
      'checked': false,
      'error': 'FFmpeg audio measurement failed (exit ${result.exitCode}).',
      'findings': <Object?>[],
    };
  }
  return parseAudioQuality(result.stderr, fps: fps);
}

/// Parses FFmpeg's measured summary without inventing a pass when statistics
/// are unavailable. Frame intervals use floor/ceil to include the audible span.
Map<String, Object?> parseAudioQuality(String stderr, {required int fps}) {
  if (fps < 1) throw ArgumentError('fps must be positive.');
  final findings = <Map<String, Object?>>[];
  final peaks = RegExp(r'Peak level dB:\s*([-+\w.]+)')
      .allMatches(stderr)
      .map((m) {
        final value = m.group(1)!;
        return value == '-inf' ? double.negativeInfinity : double.tryParse(value);
      })
      .whereType<double>()
      .where((value) => !value.isNaN)
      .toList();
  double? start;
  for (final line in stderr.split('\n')) {
    final begin = RegExp(r'silence_start:\s*([0-9.]+)').firstMatch(line);
    if (begin != null) start = double.tryParse(begin.group(1)!);
    final end = RegExp(r'silence_end:\s*([0-9.]+)').firstMatch(line);
    if (end != null && start != null) {
      final seconds = double.tryParse(end.group(1)!);
      if (seconds != null && seconds > start) {
        findings.add({
          'code': 'audio_silence',
          'severity': 'warning',
          'startFrame': (start * fps).floor(),
          'endFrame': (seconds * fps).ceil(),
          'message': 'The rendered mix is below -50 dB from $start to $seconds seconds.',
          'remedy': 'Check track timing and gain, or allow intentional silence.',
        });
      }
      start = null;
    }
  }
  final peak = peaks.isEmpty ? null : peaks.reduce((a, b) => a > b ? a : b);
  if (peak != null && peak >= -0.05) {
    findings.add({
      'code': 'audio_peak',
      'severity': 'warning',
      'peakDb': peak,
      'message': 'The mix peaks at $peak dBFS, indicating clipping risk.',
      'remedy': 'Lower the master or track gain and listen to the mix before publishing.',
    });
  }
  return {
    'checked': peak != null,
    'peakDb': peak?.isFinite ?? false ? peak : null,
    'scope': 'Full encoded audio; silence threshold -50 dB for 500 ms; peak warning at -0.05 dBFS.',
    'findings': findings,
    if (peak == null) 'error': 'No measured audio statistics were returned.',
  };
}
