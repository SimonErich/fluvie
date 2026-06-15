import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_encode_exception.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/rendering/encoding/video_probe_service.dart';
import 'package:fluvie/src/rendering/platform/process_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _MockProcessRunner extends Mock implements ProcessRunner {}

const _probeJson = '''
{
  "streams": [
    {
      "codec_type": "video",
      "codec_name": "h264",
      "width": 320,
      "height": 240,
      "nb_frames": "48"
    }
  ],
  "format": {"duration": "1.600000"}
}
''';

void main() {
  late _MockProcessRunner runner;
  late File video;

  setUp(() {
    runner = _MockProcessRunner();
    final dir = Directory.systemTemp.createTempSync('fluvie_probe_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    video = File('${dir.path}/out.mp4')..writeAsBytesSync(const [0, 1, 2]);
  });

  void stubProbe({int exitCode = 0, String stdout = _probeJson, String stderr = ''}) {
    when(() => runner.run('ffprobe', any())).thenAnswer(
      (_) async => ProcessRunResult(exitCode: exitCode, stdout: stdout, stderr: stderr),
    );
  }

  group('FfprobeVideoProbeService', () {
    test('parses codec, dimensions, nb_frames and duration', () async {
      stubProbe();
      final service = FfprobeVideoProbeService(runner: runner);

      final result = await service.probe(video.path);

      expect(result.codec, 'h264');
      expect(result.width, 320);
      expect(result.height, 240);
      expect(result.nbFrames, 48);
      expect(result.durationSeconds, closeTo(1.6, 1e-9));
    });

    test('spawns ffprobe with the exact argument array', () async {
      stubProbe();
      await FfprobeVideoProbeService(runner: runner).probe(video.path);

      verify(
        () => runner.run('ffprobe', [
          '-v',
          'error',
          '-print_format',
          'json',
          '-show_streams',
          '-show_format',
          video.path,
        ]),
      ).called(1);
    });

    test('a missing file throws before any process spawns', () async {
      final service = FfprobeVideoProbeService(runner: runner);

      await expectLater(
        () => service.probe('/nope/missing.mp4'),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('missing')),
        ),
      );
      verifyNever(() => runner.run(any(), any()));
    });

    test('a non-zero exit throws FluvieEncodeException with the stderr', () async {
      stubProbe(exitCode: 1, stdout: '', stderr: 'moov atom not found');
      final service = FfprobeVideoProbeService(runner: runner);

      await expectLater(
        () => service.probe(video.path),
        throwsA(
          isA<FluvieEncodeException>()
              .having((e) => e.exitCode, 'exitCode', 1)
              .having((e) => e.stderrTail, 'stderrTail', contains('moov')),
        ),
      );
    });

    test('malformed JSON throws a typed error', () async {
      stubProbe(stdout: 'not json at all {');
      final service = FfprobeVideoProbeService(runner: runner);

      await expectLater(
        () => service.probe(video.path),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('JSON')),
        ),
      );
    });

    test('a JSON report without a video stream throws a typed error', () async {
      stubProbe(stdout: '{"streams": [], "format": {"duration": "1.0"}}');
      final service = FfprobeVideoProbeService(runner: runner);

      await expectLater(
        () => service.probe(video.path),
        throwsA(
          isA<FluvieRenderException>().having(
            (e) => e.message,
            'message',
            contains('video-stream fields'),
          ),
        ),
      );
    });

    test('a non-numeric nb_frames throws a typed error naming the field', () async {
      stubProbe(stdout: _probeJson.replaceFirst('"48"', '"forty-eight"'));
      final service = FfprobeVideoProbeService(runner: runner);

      await expectLater(
        () => service.probe(video.path),
        throwsA(
          isA<FluvieRenderException>()
              .having((e) => e.message, 'message', contains('nb_frames'))
              .having((e) => e.message, 'message', contains('forty-eight')),
        ),
      );
    });

    test('a non-numeric duration throws a typed error naming the field', () async {
      stubProbe(stdout: _probeJson.replaceFirst('"1.600000"', '"about a second"'));
      final service = FfprobeVideoProbeService(runner: runner);

      await expectLater(
        () => service.probe(video.path),
        throwsA(
          isA<FluvieRenderException>()
              .having((e) => e.message, 'message', contains('duration'))
              .having((e) => e.message, 'message', contains('about a second')),
        ),
      );
    });

    test('a non-object JSON document throws a typed error', () async {
      stubProbe(stdout: '[1, 2, 3]');
      final service = FfprobeVideoProbeService(runner: runner);

      await expectLater(
        () => service.probe(video.path),
        throwsA(
          isA<FluvieRenderException>().having(
            (e) => e.message,
            'message',
            contains('no JSON object'),
          ),
        ),
      );
    });
  });

  group('videoProbeServiceProvider', () {
    test('resolves to FfprobeVideoProbeService by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(videoProbeServiceProvider), isA<FfprobeVideoProbeService>());
    });
  });

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });
}
