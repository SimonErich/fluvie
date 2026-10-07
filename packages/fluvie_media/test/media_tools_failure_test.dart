import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie_media/native.dart';
import 'package:test/test.dart';

void main() {
  test('probe diagnostics preserve source, exit status and bounded native stderr', () async {
    final tools = FfmpegMediaTools(
      runner: (_, _, {workingDirectory}) async =>
          (exitCode: 7, stdout: '', stderr: '${'x' * 5000}bad codec'),
    );
    addTearDown(tools.closeAsync);
    await expectLater(
      tools.probeReport('cat.mov'),
      throwsA(
        isA<MediaProcessException>()
            .having((error) => error.exitCode, 'native status', 7)
            .having((error) => error.stderr.length, 'bounded diagnostic', 4096)
            .having((error) => error.toString(), 'source and cause', contains('cat.mov'))
            .having((error) => error.toString(), 'codec failure', contains('bad codec')),
      ),
    );
    await expectLater(tools.probeReport('-unsafe'), throwsArgumentError);
    tools.close();
    await expectLater(tools.run('ffprobe', []), throwsStateError);
  });

  for (final report in ['not JSON', '[]']) {
    test('invalid ffprobe response $report produces an actionable media error', () async {
      final tools = FfmpegMediaTools(
        runner: (_, _, {workingDirectory}) async => (exitCode: 0, stdout: report, stderr: ''),
      );
      addTearDown(tools.closeAsync);
      await expectLater(
        tools.probeReport('cat.mov'),
        throwsA(
          isA<MediaProcessException>().having(
            (error) => error.message,
            'source',
            contains('cat.mov'),
          ),
        ),
      );
    });
  }

  for (final countReport in ['not JSON', '[]', '{}']) {
    test('unavailable exact counts remain explicitly estimated ($countReport)', () async {
      final tools = FfmpegMediaTools(
        runner: (_, args, {workingDirectory}) async => (
          exitCode: 0,
          stdout: args.contains('-count_frames')
              ? countReport
              : jsonEncode({
                  'streams': [
                    {
                      'codec_type': 'video',
                      'codec_name': 'h264',
                      'width': 2,
                      'height': 2,
                      'duration': '2',
                      'avg_frame_rate': '3/1',
                    },
                  ],
                }),
          stderr: '',
        ),
      );
      addTearDown(tools.closeAsync);
      final info = await tools.probe('cat.mkv');
      expect(info.frameCount, 6);
      expect(info.frameCountIsEstimated, isTrue);
    });
  }

  test('a report without a video stream rejects instead of inventing frames', () async {
    final tools = FfmpegMediaTools(
      runner: (_, _, {workingDirectory}) async => (exitCode: 0, stdout: '{}', stderr: ''),
    );
    addTearDown(tools.closeAsync);
    await expectLater(tools.probe('audio.mp3'), throwsFormatException);
  });

  for (final mode in ['failed', 'missing', 'partial']) {
    test(
      'incomplete extraction fails with source context and removes temporary files ($mode)',
      () async {
        String? staged;
        final tools = FfmpegMediaTools(
          runner: (_, args, {workingDirectory}) async {
            staged = workingDirectory;
            if (mode == 'partial') {
              await File('${workingDirectory!}/${args.last}').writeAsBytes([1]);
            }
            return (exitCode: mode == 'failed' ? 1 : 0, stdout: '', stderr: 'decode failed');
          },
        );
        addTearDown(tools.closeAsync);
        await expectLater(
          tools.extractFrames(Uri.file('/cat.mov'), [1], width: 2, height: 2),
          throwsA(
            isA<MediaProcessException>().having(
              (error) => error.message,
              'source',
              contains('cat.mov'),
            ),
          ),
        );
        expect(Directory(staged!).existsSync(), isFalse);
        await expectLater(
          tools.extractFrames(Uri.file('/cat.mov'), [1], width: 2, height: 2, decoder: '-invalid'),
          throwsArgumentError,
        );
        expect(await tools.extractFrames(Uri.file('/cat.mov'), [], width: 2, height: 2), isEmpty);
      },
    );
  }

  test('cancellation is distinct from an injected runner timeout', () async {
    final pending = Completer<MediaProcessResult>();
    final cancelled = Completer<void>();
    final tools = FfmpegMediaTools(
      runner: (_, _, {workingDirectory}) => pending.future,
      timeout: const Duration(milliseconds: 100),
    );
    addTearDown(tools.closeAsync);
    final run = expectLater(
      tools.run('probe', [], whenCancelled: cancelled.future),
      throwsA(
        isA<MediaCancelledException>().having(
          (error) => error.toString(),
          'diagnostic',
          contains('cancelled'),
        ),
      ),
    );
    cancelled.complete();
    await run;
    await expectLater(tools.run('probe', []), throwsA(isA<TimeoutException>()));
    pending.complete((exitCode: 0, stdout: '', stderr: ''));
    expect(
      () => MediaFrame(frameIndex: -1, width: 1, height: 1, rgba: Uint8List(4)),
      throwsArgumentError,
    );
  });

  test('an absent executable has a media diagnostic', () async {
    final tools = FfmpegMediaTools();
    addTearDown(tools.closeAsync);
    await expectLater(
      tools.run('/no/such/fluvie-executable', []),
      throwsA(
        isA<MediaProcessException>().having(
          (error) => error.message,
          'remedy',
          contains('Could not run'),
        ),
      ),
    );
  });

  test('timed-out children are killed and reaped before returning', () async {
    final directory = await Directory.systemTemp.createTemp('fluvie_media_timeout_');
    addTearDown(() => directory.delete(recursive: true));
    final pidFile = File('${directory.path}/child.pid');
    final tools = FfmpegMediaTools(timeout: const Duration(milliseconds: 250));
    addTearDown(tools.closeAsync);
    await expectLater(
      tools.run('/bin/sh', [
        '-c',
        'echo \$\$ > "\$1"\nexec /bin/sleep 30',
        'fluvie-child',
        pidFile.path,
      ]),
      throwsA(
        isA<MediaProcessException>().having(
          (error) => error.message,
          'timeout',
          contains('timed out'),
        ),
      ),
    );
    final child = int.parse(await pidFile.readAsString());
    expect(Process.killPid(child, ProcessSignal.sigcont), isFalse);
  }, skip: Platform.isWindows);
}
