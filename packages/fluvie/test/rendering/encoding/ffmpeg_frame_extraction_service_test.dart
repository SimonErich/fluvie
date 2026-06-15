// WI-15 (D8): the ffmpeg-backed FrameExtractionService. ProcessRunner is mocked
// (no real ffmpeg here): assert the typed arg array, the rawvideo-file parse
// into a RawFrame, a non-zero exit -> FluvieEncodeException with the stderr
// tail, and path-argument validation (no flag injection). The real-ffmpeg
// extraction is the @Tags(['ffmpeg']) integration test in the goldens/e2e set.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_encode_exception.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_frame_extraction_service.dart';
import 'package:fluvie/src/rendering/platform/process_runner.dart';
import 'package:mocktail/mocktail.dart';

class _MockProcessRunner extends Mock implements ProcessRunner {}

void main() {
  late _MockProcessRunner runner;
  late FfmpegFrameExtractionService service;

  setUp(() {
    runner = _MockProcessRunner();
    service = FfmpegFrameExtractionService(runner: runner);
  });

  /// Stubs the runner to write [bytes] to the rawvideo output file the service
  /// passed as the last argument, then succeed.
  void stubRunWriting(Uint8List bytes, {int exitCode = 0, String stderr = ''}) {
    when(
      () => runner.run(any(), any(), workingDirectory: any(named: 'workingDirectory')),
    ).thenAnswer(
      (invocation) async {
        final args = invocation.positionalArguments[1] as List<String>;
        final dir = invocation.namedArguments[#workingDirectory] as String;
        if (exitCode == 0) File('$dir/${args.last}').writeAsBytesSync(bytes);
        return ProcessRunResult(exitCode: exitCode, stdout: '', stderr: stderr);
      },
    );
  }

  test('builds the typed extraction arg array', () async {
    stubRunWriting(Uint8List(2 * 1 * 4));

    await service.extractFrame(Uri.file('/clips/intro.mp4'), 7, width: 2, height: 1);

    final captured = verify(
      () =>
          runner.run(captureAny(), captureAny(), workingDirectory: any(named: 'workingDirectory')),
    ).captured;
    expect(captured[0], 'ffmpeg');
    final args = captured[1] as List<String>;
    expect(args.sublist(0, args.length - 1), [
      '-v',
      'error',
      '-nostdin',
      '-i',
      '/clips/intro.mp4',
      '-vf',
      r'select=eq(n\,7),scale=2:1',
      '-frames:v',
      '1',
      '-f',
      'rawvideo',
      '-pix_fmt',
      'rgba',
      '-y',
    ]);
    // The last arg is the sandbox-relative rawvideo output file (no separators).
    expect(args.last, isNot(contains('/')));
    expect(args.last, isNot(startsWith('-')));
  });

  test('parses the rawvideo file into a RawFrame of the requested size', () async {
    final bytes = Uint8List.fromList(List<int>.generate(2 * 2 * 4, (i) => i % 256));
    stubRunWriting(bytes);

    final frame = await service.extractFrame(Uri.file('/clips/a.mp4'), 0, width: 2, height: 2);

    expect(frame.width, 2);
    expect(frame.height, 2);
    expect(frame.frameIndex, 0);
    expect(frame.rgba, bytes);
  });

  test('a non-zero exit throws FluvieEncodeException with the stderr tail', () async {
    stubRunWriting(Uint8List(0), exitCode: 1, stderr: 'ffmpeg: no such frame index');

    await expectLater(
      () => service.extractFrame(Uri.file('/clips/a.mp4'), 0, width: 2, height: 1),
      throwsA(
        isA<FluvieEncodeException>()
            .having((e) => e.exitCode, 'exitCode', 1)
            .having((e) => e.stderrTail, 'stderrTail', contains('no such frame index')),
      ),
    );
  });

  test('a wrong-length rawvideo payload throws a typed render error', () async {
    stubRunWriting(Uint8List(3));

    await expectLater(
      () => service.extractFrame(Uri.file('/clips/a.mp4'), 0, width: 2, height: 1),
      throwsA(
        isA<FluvieRenderException>().having((e) => e.message, 'message', contains('expected')),
      ),
    );
  });

  test('exit 0 with no frame file throws a render error naming the frame', () async {
    // The runner succeeds but writes nothing, so the output file never appears.
    when(
      () => runner.run(any(), any(), workingDirectory: any(named: 'workingDirectory')),
    ).thenAnswer((_) async => const ProcessRunResult(exitCode: 0, stdout: '', stderr: ''));

    await expectLater(
      () => service.extractFrame(Uri.file('/clips/a.mp4'), 5, width: 2, height: 1),
      throwsA(
        isA<FluvieRenderException>().having((e) => e.message, 'message', contains('frame 5')),
      ),
    );
  });

  test('a stderr longer than the tail length is truncated to its tail', () async {
    // 4096 is the tail budget; a 5000-char head plus a marker must drop the
    // head and keep only the trailing 4096 characters (incl. the marker).
    final head = 'x' * 5000;
    stubRunWriting(Uint8List(0), exitCode: 1, stderr: '${head}TAIL_MARKER');

    await expectLater(
      () => service.extractFrame(Uri.file('/clips/a.mp4'), 0, width: 2, height: 1),
      throwsA(
        isA<FluvieEncodeException>().having(
          (e) => e.stderrTail,
          'stderrTail',
          allOf(contains('TAIL_MARKER'), hasLength(4096)),
        ),
      ),
    );
  });

  test('an empty source path is rejected before any run', () async {
    await expectLater(
      () => service.extractFrame(Uri.parse(''), 0, width: 2, height: 1),
      throwsA(isA<ArgumentError>()),
    );
    verifyNever(
      () => runner.run(any(), any(), workingDirectory: any(named: 'workingDirectory')),
    );
  });

  group('path-argument validation (no flag injection)', () {
    test('a path that looks like a flag is rejected before any run', () async {
      await expectLater(
        () => service.extractFrame(Uri.file('-evil.mp4'), 0, width: 2, height: 1),
        throwsA(isA<ArgumentError>()),
      );
      verifyNever(
        () => runner.run(any(), any(), workingDirectory: any(named: 'workingDirectory')),
      );
    });

    test('a negative frame index is rejected before any run', () async {
      await expectLater(
        () => service.extractFrame(Uri.file('/clips/a.mp4'), -1, width: 2, height: 1),
        throwsA(isA<ArgumentError>()),
      );
      verifyNever(
        () => runner.run(any(), any(), workingDirectory: any(named: 'workingDirectory')),
      );
    });
  });
}
