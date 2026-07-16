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

/// What ffprobe really reports for a VP9-with-alpha webm: Matroska stores no
/// frame count and no per-stream duration, so both are absent and only the
/// container duration, the frame rate, and the `ALPHA_MODE` tag are there.
const _webmJson = '''
{
  "streams": [
    {
      "codec_type": "video",
      "codec_name": "vp9",
      "width": 1920,
      "height": 1080,
      "r_frame_rate": "30/1",
      "avg_frame_rate": "30/1",
      "tags": {"ALPHA_MODE": "1", "DURATION": "00:00:03.533000000"}
    }
  ],
  "format": {"duration": "3.550000"}
}
''';

/// A `-count_frames` report naming an exact count.
String _countJson(String frames) => '{"streams": [{"nb_read_frames": "$frames"}]}';

/// A `-count_frames` report that names no count (ffprobe read no frames).
const _noCountJson = '{"streams": [{}]}';

void main() {
  late _MockProcessRunner runner;
  late File video;

  setUp(() {
    runner = _MockProcessRunner();
    final dir = Directory.systemTemp.createTempSync('fluvie_probe_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    video = File('${dir.path}/out.mp4')..writeAsBytesSync(const [0, 1, 2]);
  });

  /// Stubs both ffprobe passes: [stdout] answers the report pass, and
  /// [countStdout] the `-count_frames` pass the frame-count derivation runs.
  void stubProbe({
    int exitCode = 0,
    String stdout = _probeJson,
    String stderr = '',
    String countStdout = _noCountJson,
    int countExitCode = 0,
  }) {
    when(() => runner.run('ffprobe', any())).thenAnswer((invocation) async {
      final args = invocation.positionalArguments[1] as List<String>;
      if (args.contains('-count_frames')) {
        return ProcessRunResult(exitCode: countExitCode, stdout: countStdout, stderr: '');
      }
      return ProcessRunResult(exitCode: exitCode, stdout: stdout, stderr: stderr);
    });
  }

  /// The `-count_frames` invocations the service made.
  List<List<String>> countPasses() => verify(
    () => runner.run('ffprobe', captureAny()),
  ).captured.cast<List<String>>().where((args) => args.contains('-count_frames')).toList();

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

    test('reports hasAudio false when the report has only a video stream', () async {
      stubProbe();
      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);
      expect(result.hasAudio, isFalse);
    });

    test('reports hasAudio true when the report carries an audio stream', () async {
      stubProbe(
        stdout: '''
{
  "streams": [
    {"codec_type": "video", "codec_name": "h264", "width": 320, "height": 240, "nb_frames": "48"},
    {"codec_type": "audio", "codec_name": "aac"}
  ],
  "format": {"duration": "1.6"}
}
''',
      );
      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);
      expect(result.hasAudio, isTrue);
    });
  });

  // Matroska/WebM stores neither a frame count nor a per-stream duration, so
  // the probe has to derive both or a .webm clip cannot render at all.
  group('a container that reports no nb_frames (Matroska/WebM)', () {
    test('counts the frames exactly with a -count_frames pass', () async {
      stubProbe(stdout: _webmJson, countStdout: _countJson('106'));

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.nbFrames, 106);
    });

    test('spawns the -count_frames pass with the exact argument array', () async {
      stubProbe(stdout: _webmJson, countStdout: _countJson('106'));
      await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(countPasses(), [
        [
          '-v',
          'error',
          '-count_frames',
          '-select_streams',
          'v:0',
          '-print_format',
          'json',
          '-show_entries',
          'stream=nb_read_frames',
          video.path,
        ],
      ]);
    });

    test('prefers the exact count over the duration estimate', () async {
      stubProbe(stdout: _webmJson, countStdout: _countJson('106'));

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(
        result.nbFrames,
        106,
        reason: 'the duration estimate (3.55s x 30fps) would round to 107',
      );
    });

    test('falls back to duration x frame rate when the count pass reports none', () async {
      stubProbe(stdout: _webmJson);

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.nbFrames, 107, reason: '3.55s x 30fps, rounded');
    });

    test('falls back to duration x frame rate when the count pass exits non-zero', () async {
      stubProbe(stdout: _webmJson, countExitCode: 1, countStdout: '');

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.nbFrames, 107);
    });

    test('falls back to duration x frame rate when the count pass emits garbage', () async {
      stubProbe(stdout: _webmJson, countStdout: 'not json at all {');

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.nbFrames, 107);
    });

    test('takes the duration from the container when the stream reports none', () async {
      stubProbe(stdout: _webmJson, countStdout: _countJson('106'));

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.durationSeconds, closeTo(3.55, 1e-9));
    });

    test('throws the typed error when neither a count nor a duration is available', () async {
      stubProbe(
        stdout: '''
{
  "streams": [{"codec_type": "video", "codec_name": "vp9", "width": 1920, "height": 1080}],
  "format": {}
}
''',
      );
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

    test('throws when the frame rate is unknown (0/0) and no count is available', () async {
      stubProbe(
        stdout: '''
{
  "streams": [
    {
      "codec_type": "video",
      "codec_name": "vp9",
      "width": 1920,
      "height": 1080,
      "r_frame_rate": "0/0",
      "avg_frame_rate": "0/0"
    }
  ],
  "format": {"duration": "3.55"}
}
''',
      );
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
  });

  group('the -count_frames pass', () {
    test('never runs for a container that reports its own nb_frames', () async {
      stubProbe();

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.nbFrames, 48);
      expect(countPasses(), isEmpty, reason: 'counting decodes the file; do not pay for it');
    });

    test('runs once for a container that reports no nb_frames', () async {
      stubProbe(stdout: _webmJson, countStdout: _countJson('106'));

      await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(countPasses(), hasLength(1));
    });
  });

  group('the frame rate is a rational', () {
    /// A report with no frame count, so the derived count exposes the parsed
    /// frame rate: `nbFrames == round(duration * fps)`.
    String rateJson(String rate, String duration) =>
        '''
{
  "streams": [
    {
      "codec_type": "video",
      "codec_name": "vp9",
      "width": 320,
      "height": 240,
      "r_frame_rate": "$rate"
    }
  ],
  "format": {"duration": "$duration"}
}
''';

    test('30/1 reads as 30fps', () async {
      stubProbe(stdout: rateJson('30/1', '2.0'));

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.nbFrames, 60);
    });

    test('30000/1001 reads as 29.97fps, not 30', () async {
      stubProbe(stdout: rateJson('30000/1001', '100.1'));

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.nbFrames, 3000, reason: 'a naive 30fps read would give 3003');
    });

    test('a bare number reads as a rate', () async {
      stubProbe(stdout: rateJson('25', '4.0'));

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.nbFrames, 100);
    });

    test('falls back to r_frame_rate when avg_frame_rate is unknown', () async {
      stubProbe(
        stdout: '''
{
  "streams": [
    {
      "codec_type": "video",
      "codec_name": "vp9",
      "width": 320,
      "height": 240,
      "r_frame_rate": "24/1",
      "avg_frame_rate": "0/0"
    }
  ],
  "format": {"duration": "2.0"}
}
''',
      );

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.nbFrames, 48);
    });
  });

  // fps feeds the clip resampler: it decides which source frame each
  // composition frame paints, so a wrong rate is wrong pixels, not a wrong
  // number.
  group('the reported fps', () {
    test('is the declared rate, not the rate derived from the duration', () async {
      // The reason declaredFps exists: this webm's container duration (3.55s)
      // spans its audio tail, so frames-over-duration reads 29.86 for a clip
      // that really runs at 30.
      stubProbe(stdout: _webmJson, countStdout: _countJson('106'));

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.declaredFps, 30);
      expect(result.fps, 30);
      expect(
        result.nbFrames / result.durationSeconds,
        closeTo(29.86, 0.01),
        reason: 'the derived rate is the wrong answer the declared rate replaces',
      );
    });

    test('trusts avg_frame_rate over r_frame_rate, which lies for a variable rate', () async {
      // r_frame_rate is the lowest rate that can represent every timestamp
      // exactly, so a variable-rate source (a screen capture, phone footage)
      // reports a multiple of its real rate: 600/1 for a clip running at 30.
      // Trusting it would hand the resampler a rate 20x the truth, and every
      // composition frame past the first would paint the clip's last source
      // frame. avg_frame_rate is the honest rate for those files.
      stubProbe(
        stdout: '''
{
  "streams": [
    {
      "codec_type": "video",
      "codec_name": "h264",
      "width": 320,
      "height": 240,
      "nb_frames": "300",
      "duration": "10.0",
      "r_frame_rate": "600/1",
      "avg_frame_rate": "30/1"
    }
  ],
  "format": {"duration": "10.0"}
}
''',
      );

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.fps, 30);
      expect(result.fps, isNot(600));
    });

    test('keeps an NTSC declared rate at 29.97 rather than rounding to 30', () async {
      stubProbe(
        stdout: _webmJson.replaceAll('"30/1"', '"30000/1001"'),
        countStdout: _countJson('106'),
      );

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.fps, closeTo(29.97002997, 1e-6));
      expect(result.fps, isNot(30));
    });

    test('falls back to the derived rate when the rate is unknown (0/0)', () async {
      stubProbe(stdout: _webmJson.replaceAll('"30/1"', '"0/0"'), countStdout: _countJson('106'));

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.declaredFps, isNull);
      expect(result.fps, closeTo(106 / 3.55, 1e-9));
    });

    test('falls back to the derived rate when no rate is reported at all', () async {
      stubProbe();

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.declaredFps, isNull);
      expect(result.fps, closeTo(30, 1e-9), reason: '48 frames over 1.6s');
    });

    test('a zero duration with no declared rate reads as the frame count', () async {
      const result = VideoProbeResult(
        codec: 'h264',
        width: 2,
        height: 2,
        nbFrames: 30,
        durationSeconds: 0,
      );

      expect(result.fps, 30, reason: 'the pre-existing guard against dividing by zero');
    });
  });

  group('duration', () {
    test('prefers the stream duration over the container duration', () async {
      stubProbe(
        stdout: '''
{
  "streams": [
    {
      "codec_type": "video",
      "codec_name": "h264",
      "width": 320,
      "height": 240,
      "nb_frames": "48",
      "duration": "1.500000"
    }
  ],
  "format": {"duration": "9.900000"}
}
''',
      );

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.durationSeconds, closeTo(1.5, 1e-9));
    });

    test('derives from the frame count and frame rate when neither is reported', () async {
      stubProbe(
        stdout: '''
{
  "streams": [
    {
      "codec_type": "video",
      "codec_name": "h264",
      "width": 320,
      "height": 240,
      "nb_frames": "48",
      "r_frame_rate": "24/1"
    }
  ],
  "format": {}
}
''',
      );

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.durationSeconds, closeTo(2, 1e-9));
    });
  });

  group('alpha detection', () {
    test('reads hasAlpha from the Matroska ALPHA_MODE tag', () async {
      stubProbe(stdout: _webmJson, countStdout: _countJson('106'));

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.hasAlpha, isTrue);
      expect(result.codec, 'vp9');
    });

    test('a lowercase alpha_mode tag reads the same', () async {
      stubProbe(
        stdout: _webmJson.replaceFirst('ALPHA_MODE', 'alpha_mode'),
        countStdout: _countJson('106'),
      );

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.hasAlpha, isTrue);
    });

    test('ALPHA_MODE 0 is not alpha', () async {
      stubProbe(
        stdout: _webmJson.replaceFirst('"ALPHA_MODE": "1"', '"ALPHA_MODE": "0"'),
        countStdout: _countJson('106'),
      );

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.hasAlpha, isFalse);
    });

    test('a stream with no tags is not alpha', () async {
      stubProbe();

      final result = await FfprobeVideoProbeService(runner: runner).probe(video.path);

      expect(result.hasAlpha, isFalse);
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
