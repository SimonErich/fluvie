import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie_media/native.dart';
import 'package:test/test.dart';

void main() {
  test('batch planning sorts, deduplicates and bounds memory', () {
    expect(frameBatches([5, 0, 5, 2], width: 2, height: 1, maxBytes: 16), [
      [0, 2],
      [5],
    ]);
    expect(() => frameBatches([-1], width: 2, height: 1), throwsArgumentError);
    expect(() => frameBatches([0], width: 2, height: 1, maxBytes: 7), throwsArgumentError);
  });

  test('native batch returns exact pixels and launches once', () async {
    var calls = 0;
    final tools = FfmpegMediaTools(
      ffmpegPath: '/fixture/ffmpeg',
      runner: (executable, args, {workingDirectory}) async {
        calls++;
        expect(executable, '/fixture/ffmpeg');
        expect(args, contains(r'select=eq(n\,0)+eq(n\,5),scale=2:1'));
        expect(args, containsAllInOrder(['-c:v', 'libvpx-vp9', '-i']));
        final pixels = Uint8List.fromList([...List.filled(8, 10), ...List.filled(8, 20)]);
        await File('$workingDirectory/${args.last}').writeAsBytes(pixels);
        return (exitCode: 0, stdout: '', stderr: '');
      },
    );
    addTearDown(tools.close);
    final frames = await tools.extractFrames(
      Uri.file('/fixture/alpha.webm'),
      [5, 0, 5],
      width: 2,
      height: 1,
      decoder: 'libvpx-vp9',
    );
    expect(calls, 1);
    expect(frames.keys, [0, 5]);
    expect(frames[0]!.rgba, List.filled(8, 10));
    expect(frames[5]!.rgba, List.filled(8, 20));
  });

  test('missing source frames fail without synthesizing duplicates', () async {
    final tools = FfmpegMediaTools(
      runner: (_, args, {workingDirectory}) async {
        await File('$workingDirectory/${args.last}').writeAsBytes(Uint8List(8));
        return (exitCode: 0, stdout: '', stderr: '');
      },
    );
    addTearDown(tools.close);
    await expectLater(
      tools.extractFrames(Uri.file('/fixture/source.mp4'), [0, 5], width: 2, height: 1),
      throwsA(
        isA<MediaProcessException>().having(
          (e) => e.message,
          'diagnostic',
          contains('source frame bounds'),
        ),
      ),
    );
  });

  test('source metadata preserves display rotation, alpha and audio', () {
    final info = MediaSourceInfo.fromReport({
      'streams': [
        {
          'codec_type': 'video',
          'codec_name': 'prores',
          'pix_fmt': 'yuva444p12le',
          'width': 1920,
          'height': 1080,
          'avg_frame_rate': '30/1',
          'nb_frames': '90',
          'duration': '3',
          'side_data_list': [
            {'rotation': -90},
          ],
        },
        {'codec_type': 'audio'},
      ],
    });
    expect(info.width, 1080);
    expect(info.height, 1920);
    expect(info.hasAlpha, isTrue);
    expect(info.hasAudio, isTrue);
    expect(info.rotationDegrees, 270);
    expect(info.frameCountIsEstimated, isFalse);
  });

  test('estimated frame counts are explicitly distinguished from counted frames', () {
    final report = {
      'streams': [
        {
          'codec_type': 'video',
          'width': 16,
          'height': 8,
          'avg_frame_rate': '30/1',
          'duration': '2',
        },
      ],
    };
    final estimated = MediaSourceInfo.fromReport(report);
    expect(estimated.frameCount, 60);
    expect(estimated.toJson()['frameCountIsEstimated'], isTrue);
    final counted = MediaSourceInfo.fromReport(report, countedFrames: 58);
    expect(counted.frameCount, 58);
    expect(counted.frameCountIsEstimated, isFalse);
  });

  test('native executables respect exact environment overrides', () {
    expect(
      resolveMediaExecutable('ffmpeg', environment: {'FLUVIE_FFMPEG': '/custom/encode'}),
      '/custom/encode',
    );
    expect(
      resolveMediaExecutable('ffprobe', environment: {'FLUVIE_FFPROBE': '/custom/probe'}),
      '/custom/probe',
    );
    expect(
      resolveMediaExecutable(
        'ffprobe',
        explicit: '/explicit',
        environment: {'FLUVIE_FFPROBE': '/custom'},
      ),
      '/explicit',
    );
  });

  test('invalid metadata gives a source diagnostic rather than numeric cast errors', () {
    expect(() => MediaSourceInfo.fromReport({'streams': 'invalid'}), throwsFormatException);
    expect(
      () => MediaSourceInfo.fromReport({
        'streams': [
          {
            'codec_type': 'video',
            'width': 16,
            'height': 8,
            'avg_frame_rate': 'Infinity/1',
            'duration': 'NaN',
            'nb_frames': 'NaN',
          },
        ],
      }),
      throwsFormatException,
    );
  });
}
