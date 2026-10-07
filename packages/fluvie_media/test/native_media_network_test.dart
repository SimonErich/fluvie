import 'dart:io';

import 'package:fluvie_media/native.dart';
import 'package:test/test.dart';

void main() {
  test('native probing rejects network sources before starting a process', () async {
    var processStarted = false;
    final tools = FfmpegMediaTools(
      runner: (_, _, {workingDirectory}) async {
        processStarted = true;
        return (exitCode: 0, stdout: '{}', stderr: '');
      },
    );
    addTearDown(tools.closeAsync);

    await expectLater(tools.probeReport('https://example.com/clip.mp4'), throwsArgumentError);
    expect(processStarted, isFalse);
  });

  test('metadata probes explicitly restrict native input protocols to local files', () async {
    final tools = FfmpegMediaTools(
      runner: (_, arguments, {workingDirectory}) async {
        expect(arguments, containsAllInOrder(['-protocol_whitelist', 'file', 'clip.mp4']));
        return (exitCode: 0, stdout: '{}', stderr: '');
      },
    );
    addTearDown(tools.closeAsync);

    expect(await tools.probeReport('clip.mp4'), isEmpty);
  });

  test('frame-count probes retain the local-file protocol policy', () async {
    final tools = FfmpegMediaTools(
      runner: (_, arguments, {workingDirectory}) async {
        expect(arguments, containsAllInOrder(['-protocol_whitelist', 'file', 'clip.mp4']));
        return (
          exitCode: 0,
          stdout: arguments.contains('-count_frames')
              ? '{"streams":[{"nb_read_frames":"2"}]}'
              : '{"streams":[{"codec_type":"video","width":2,"height":2,'
                    '"avg_frame_rate":"2/1","duration":"1"}]}',
          stderr: '',
        );
      },
    );
    addTearDown(tools.closeAsync);

    final source = await tools.probe('clip.mp4');
    expect(source.frameCount, 2);
    expect(source.frameCountIsEstimated, isFalse);
  });

  test('display-timeline probes retain the local-file protocol policy', () async {
    final tools = FfmpegMediaTools(
      runner: (_, arguments, {workingDirectory}) async {
        expect(arguments, containsAllInOrder(['-protocol_whitelist', 'file', 'clip.mp4']));
        return (
          exitCode: 0,
          stdout:
              '{"frames":[{"best_effort_timestamp_time":"0",'
              '"duration_time":"1","key_frame":1}]}',
          stderr: '',
        );
      },
    );
    addTearDown(tools.closeAsync);

    final timeline = await tools.probeTimeline('clip.mp4');
    expect(timeline.frameCount, 1);
    expect(timeline.durationSeconds, 1);
  });

  test('batched decoding restricts input protocols without changing decoded pixels', () async {
    final tools = FfmpegMediaTools(
      runner: (_, arguments, {workingDirectory}) async {
        expect(
          arguments,
          containsAllInOrder(['-protocol_whitelist', 'file', '-i', '/fixture/clip.mp4']),
        );
        await File('$workingDirectory/${arguments.last}').writeAsBytes([1, 2, 3, 255]);
        return (exitCode: 0, stdout: '', stderr: '');
      },
    );
    addTearDown(tools.closeAsync);

    final frames = await tools.extractFrames(
      Uri.file('/fixture/clip.mp4'),
      [0],
      width: 1,
      height: 1,
    );
    expect(frames[0]!.rgba, [1, 2, 3, 255]);
  });

  test('streaming decoding uses the injected process adapter and local input policy', () async {
    final tools = FfmpegMediaTools(
      runner: (_, _, {workingDirectory}) async => (
        exitCode: 0,
        stdout:
            '{"frames":[{"best_effort_timestamp_time":"0",'
            '"duration_time":"1","key_frame":1}]}',
        stderr: '',
      ),
      processStarter: (_, arguments, {workingDirectory}) async {
        expect(
          arguments,
          containsAllInOrder(['-protocol_whitelist', 'file', '-i', '/fixture/clip.mp4']),
        );
        return _DecodedProcess();
      },
    );
    addTearDown(tools.closeAsync);

    final session = await tools.openFrameSession(
      Uri.file('/fixture/clip.mp4'),
      width: 1,
      height: 1,
    );
    final frames = await session.readFrames([0]);
    expect(frames[0]!.rgba, [1, 2, 3, 255]);
    await session.close();
  });

  test('contact-sheet encoding retains local input restrictions and failure diagnostics', () async {
    final tools = FfmpegMediaTools(
      ffmpegPath: '/fixture/encode',
      ffprobePath: '/fixture/probe',
      processStarter: (_, _, {workingDirectory}) async => _DecodedProcess(),
      runner: (executable, arguments, {workingDirectory}) async {
        if (executable == '/fixture/encode') {
          expect(
            arguments,
            containsAllInOrder(['-protocol_whitelist', 'file', '-i', 'pictures.rgba']),
          );
          return (exitCode: 7, stdout: '', stderr: 'encoder refused output');
        }
        return (
          exitCode: 0,
          stdout: arguments.contains('-show_frames')
              ? '{"frames":[{"best_effort_timestamp_time":"0",'
                    '"duration_time":"1","key_frame":1}]}'
              : '{"streams":[{"codec_type":"video","width":1,"height":1,'
                    '"avg_frame_rate":"1/1","nb_frames":"1","duration":"1"}]}',
          stderr: '',
        );
      },
    );
    addTearDown(tools.closeAsync);

    await expectLater(
      tools.contactSheet(
        Uri.file('/fixture/clip.mp4'),
        outputPath: '${Directory.systemTemp.path}/unused-fluvie-sheet.png',
        samples: 1,
        columns: 1,
        cellWidth: 1,
        cellHeight: 1,
      ),
      throwsA(
        isA<MediaProcessException>()
            .having((error) => error.exitCode, 'native status', 7)
            .having((error) => error.stderr, 'diagnostic', 'encoder refused output'),
      ),
    );
  });

  test('all source operations reject file URIs with foreign authorities', () async {
    var processStarted = false;
    final tools = FfmpegMediaTools(
      runner: (_, _, {workingDirectory}) async {
        processStarted = true;
        return (exitCode: 0, stdout: '{}', stderr: '');
      },
    );
    addTearDown(tools.closeAsync);
    final source = Uri.parse('file://example.com/clip.mp4');
    final operations = <String, Future<Object?> Function()>{
      'metadata': () => tools.probeReport('$source'),
      'timeline': () => tools.probeTimeline('$source'),
      'batch': () => tools.extractFrames(source, [0], width: 1, height: 1),
      'session': () => tools.openFrameSession(source, width: 1, height: 1),
      'contact sheet': () => tools.contactSheet(source, outputPath: 'unused-sheet.png'),
    };
    for (final entry in operations.entries) {
      await expectLater(entry.value(), throwsArgumentError, reason: entry.key);
    }
    expect(processStarted, isFalse);
  });

  test('localhost file URIs preserve the local filename passed to native tools', () async {
    final path = Platform.isWindows ? r'C:\fixture\my clip.mp4' : '/fixture/my clip.mp4';
    final tools = FfmpegMediaTools(
      runner: (_, arguments, {workingDirectory}) async {
        expect(arguments.last, path);
        return (exitCode: 0, stdout: '{}', stderr: '');
      },
    );
    addTearDown(tools.closeAsync);

    final source = Uri.file(path, windows: Platform.isWindows).replace(host: 'localhost');
    expect(await tools.probeReport('$source'), isEmpty);
  });
}

class _DecodedProcess implements Process {
  @override
  Future<int> get exitCode async => 0;

  @override
  int get pid => 1;

  @override
  Stream<List<int>> get stdout => Stream.value([1, 2, 3, 255]);

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  IOSink get stdin => throw UnsupportedError('The decoder does not use standard input.');

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}
