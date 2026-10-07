part of 'output_verification.dart';

Future<Map<String, Object?>> _verifySequence(
  FfmpegMediaTools tools,
  String path,
  Map<String, Object?> expected,
  bool strictDecode,
  Future<void>? whenCancelled,
) async {
  final files = Directory(path).listSync(followLinks: false).whereType<File>().toList()
    ..sort((left, right) => left.path.compareTo(right.path));
  final mismatches = <Map<String, Object?>>[];
  var observed = <String, Object?>{
    'codec': 'png',
    'container': 'png_sequence',
    'hasAudio': false,
    'frameCount': files.length,
  };
  final frameIntent = <String, Object?>{
    for (final key in ['width', 'height', 'codec', 'pixelFormat', 'hasAlpha'])
      if (expected.containsKey(key)) key: expected[key],
  };
  if (files.isEmpty) {
    mismatches.add({'code': 'frameCount', 'expected': 'at least one picture', 'actual': 0});
  }
  for (final file in files) {
    try {
      final facts = _mediaFacts(await tools.probeReport(file.path, whenCancelled: whenCancelled));
      if (facts['codec'] != 'png' || facts['width'] == null) {
        mismatches.add({
          'code': 'picture',
          'expected': 'readable PNG',
          'actual': facts['codec'],
          'path': file.path,
        });
        continue;
      }
      if (!observed.containsKey('width')) {
        observed = {...facts, ...observed}
          ..remove('fps')
          ..remove('durationSeconds');
        frameIntent
          ..putIfAbsent('width', () => facts['width'])
          ..putIfAbsent('height', () => facts['height']);
      }
      mismatches.addAll(
        _compareIntent(frameIntent, facts).map((mismatch) => {...mismatch, 'path': file.path}),
      );
      if (strictDecode) {
        final decoded = await tools.run(tools.ffmpegPath, [
          '-v',
          'error',
          '-xerror',
          '-nostdin',
          '-i',
          file.path,
          '-f',
          'null',
          '-',
        ], whenCancelled: whenCancelled);
        if (decoded.exitCode != 0) {
          mismatches.add({
            'code': 'decode',
            'expected': 'complete PNG decode',
            'actual': decoded.stderr,
            'path': file.path,
          });
        }
      }
    } on MediaProcessException catch (error) {
      mismatches.add({
        'code': 'picture',
        'expected': 'readable PNG',
        'actual': error.toString(),
        'path': file.path,
      });
    }
  }
  mismatches.addAll(_compareIntent(expected, observed));
  return {
    'schemaVersion': 1,
    'ok': mismatches.isEmpty,
    'strictDecode': strictDecode,
    'observed': observed,
    'mismatches': mismatches,
  };
}
