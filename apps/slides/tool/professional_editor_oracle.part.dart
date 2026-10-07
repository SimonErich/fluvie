part of 'professional_editor_journey.dart';

/// Samples decoded video outside the lower-third title area. The fixed 48-frame
/// scene has a six-frame background tail: overlapping the second 24-frame clip
/// moves its full window from [24, 48) to [18, 42), without resizing the scene.
Future<Map<String, Object?>> _decodedContent(String path) async {
  const frames = [0, 20, 41, 47];
  const expected = [
    [238, 12, 12], // Red fixture after exposure +0.15 and saturation 0.8.
    [119, 6, 134], // Mid-crossfade: both source pictures contribute.
    [0, 0, 255], // Last active blue frame.
    [0, 0, 0], // Authored scene background after the incoming clip ends.
  ];
  const width = 64;
  const height = 36;
  final video = await Process.run('ffmpeg', [
    '-v',
    'error',
    '-i',
    path,
    '-vf',
    "select='eq(n,0)+eq(n,20)+eq(n,41)+eq(n,47)',scale=64:36:flags=area",
    '-fps_mode',
    'passthrough',
    '-f',
    'rawvideo',
    '-pix_fmt',
    'rgb24',
    'pipe:1',
  ], stdoutEncoding: null);
  expect(video.exitCode, 0, reason: '${video.stderr}');
  final pixels = video.stdout as List<int>;
  const frameBytes = width * height * 3;
  expect(pixels, hasLength(frames.length * frameBytes));
  final samples = <Map<String, Object?>>[];
  var pixelsMatch = true;
  for (var frame = 0; frame < frames.length; frame++) {
    // Average small upper-picture patches, avoiding title glyphs and edges.
    for (final x in [10, 32, 53]) {
      final rgb = <double>[
        for (var channel = 0; channel < 3; channel++)
          [
                for (var y = 6; y <= 10; y++)
                  for (var px = x - 2; px <= x + 2; px++)
                    pixels[frame * frameBytes + (y * width + px) * 3 + channel],
              ].reduce((a, b) => a + b) /
              25,
      ];
      final tolerance = frames[frame] == 20 ? 20 : 12;
      final matches = List.generate(
        3,
        (channel) => (rgb[channel] - expected[frame][channel]).abs() <= tolerance,
      ).every((matches) => matches);
      pixelsMatch = pixelsMatch && matches;
      samples.add({
        'frame': frames[frame],
        'patchCenter': [x, 8],
        'meanRgb': rgb,
        'expectedRgb': expected[frame],
        'channelTolerance': tolerance,
        'passed': matches,
      });
    }
  }
  final audio = await Process.run('ffmpeg', [
    '-v',
    'error',
    '-i',
    path,
    '-vn',
    '-ac',
    '1',
    '-ar',
    '8000',
    '-f',
    'f32le',
    'pipe:1',
  ], stdoutEncoding: null);
  expect(audio.exitCode, 0, reason: '${audio.stderr}');
  final data = ByteData.sublistView(Uint8List.fromList(audio.stdout as List<int>));
  expect(data.lengthInBytes % 4, 0);
  final count = data.lengthInBytes ~/ 4;
  expect(count, greaterThan(0));
  var sumSquares = 0.0;
  var peak = 0.0;
  for (var i = 0; i < count; i++) {
    final value = data.getFloat32(i * 4, Endian.little);
    expect(value.isFinite, isTrue, reason: 'Decoded PCM must contain finite samples');
    sumSquares += value * value;
    peak = math.max(peak, value.abs());
  }
  final rms = math.sqrt(sumSquares / count);
  final seconds = count / 8000;
  final audioMatches = rms > 0.01 && rms < 0.5 && peak <= 1 && seconds > 3.9 && seconds < 4.1;
  return {
    'passed': pixelsMatch && audioMatches,
    'pixels': {
      'sampleSize': [width, height],
      'patchSize': [5, 5],
      'samples': samples,
    },
    'audio': {
      'sampleRate': 8000,
      'channels': 1,
      'samples': count,
      'durationSeconds': seconds,
      'rms': rms,
      'peak': peak,
      'passed': audioMatches,
    },
    'fixedSceneBackgroundTail': {'fromFrame': 42, 'toFrameExclusive': 48},
  };
}

Future<void> _verifyJourney(
  WidgetTester tester,
  Directory directory,
  _AuthoredJourney authored,
) async {
  final outputs = authored.outputs;
  final digest = authored.digest;
  final reports = <Map<String, Object?>>[];
  await tester.runAsync(() async {
    for (final output in outputs) {
      final probe = await Process.run('ffprobe', [
        '-v',
        'error',
        '-count_frames',
        '-show_streams',
        '-show_format',
        '-of',
        'json',
        output,
      ]);
      expect(probe.exitCode, 0, reason: '${probe.stderr}');
      final json = jsonDecode(probe.stdout as String) as Map<String, Object?>;
      final streams = (json['streams']! as List).cast<Map<String, Object?>>();
      final picture = streams.firstWhere((stream) => stream['codec_type'] == 'video');
      expect(picture['nb_read_frames'], '48');
      expect(picture['width'], output.contains('1080p') ? 1920 : 1280);
      expect(streams.any((stream) => stream['codec_type'] == 'audio'), isTrue);
      reports.add({'path': output, 'probe': json, 'decodedContent': await _decodedContent(output)});
    }
    File('${directory.path}/verification.json').writeAsStringSync(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'renderDigest': digest, 'savedAndReopenedIdentically': true, 'outputs': reports}),
    );
  });
  for (final report in reports) {
    final content = report['decodedContent']! as Map<String, Object?>;
    expect(
      content['passed'],
      isTrue,
      reason: 'Decoded media content differs from the authored fixtures: ${jsonEncode(report)}',
    );
  }
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}
