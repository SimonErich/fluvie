import 'dart:async';
import 'dart:io';

import 'package:fluvie_media/native.dart';
import 'package:test/test.dart';

import 'fakes/session_fixture.dart';

void main() {
  final native = Platform.environment['FLUVIE_TEST_NATIVE_MEDIA'] == '1' && !Platform.isWindows;
  final source = Uri.file('/fixture/cat.mp4');

  test('invalid session geometry and decoder names fail before probing', () async {
    var calls = 0;
    final tools = FfmpegMediaTools(
      runner: (_, _, {workingDirectory}) async {
        calls++;
        return (exitCode: 0, stdout: '{}', stderr: '');
      },
    );
    addTearDown(tools.closeAsync);
    await expectLater(tools.openFrameSession(source, width: 0, height: 1), throwsArgumentError);
    for (final decoder in ['', '-v']) {
      await expectLater(
        tools.openFrameSession(source, width: 1, height: 1, decoder: decoder),
        throwsArgumentError,
      );
    }
    expect(calls, 0);
    await tools.closeAsync();
    await expectLater(tools.openFrameSession(source, width: 1, height: 1), throwsStateError);
  });

  test('repeating the last frame reuses pixels without starting or consuming a decoder', () async {
    final fixture = await sessionFixture();
    final session = await fixture.tools.openFrameSession(source, width: 1, height: 1);
    final first = (await session.readFrames([1]))[1]!;
    final consumed = session.framesRead;
    expect((await session.readFrames([1, 1]))[1], same(first));
    expect(session.framesRead, consumed);
    expect(session.decoderStarts, 1);
    await expectLater(session.readFrames([-1]), throwsRangeError);
    await expectLater(session.readFrames([200]), throwsRangeError);
  }, skip: !native);

  test('a partial decoder picture retains exit status, source and native stderr', () async {
    final fixture = await sessionFixture(
      body: r'''
sys.stderr.write('fixture truncated picture\n')
sys.stdout.buffer.write(b'abc')
sys.exit(7)''',
    );
    final session = await fixture.tools.openFrameSession(source, width: 1, height: 1);
    await expectLater(
      session.readFrames([0]),
      throwsA(
        isA<MediaProcessException>()
            .having((error) => error.exitCode, 'exit status', 7)
            .having((error) => error.message, 'source', contains('cat.mp4'))
            .having((error) => error.stderr, 'stderr', contains('truncated picture')),
      ),
    );
  }, skip: !native);

  test('a blocked picture times out and its owned decoder is reaped', () async {
    final fixture = await sessionFixture(
      body: 'time.sleep(30)',
      timeout: const Duration(milliseconds: 100),
    );
    final session = await fixture.tools.openFrameSession(source, width: 1, height: 1);
    await expectLater(
      session.readFrames([0]),
      throwsA(
        isA<MediaProcessException>().having(
          (error) => error.message,
          'message',
          contains('timed out'),
        ),
      ),
    );
    final pid = int.parse(await fixture.pid.readAsString());
    expect(Process.killPid(pid, ProcessSignal.sigcont), isFalse);
    await session.close();
  }, skip: !native);

  for (final diagnostic in ['pass', r"sys.stderr.write('n: 0 pts: 0 pts_time:99.0 value \n')"]) {
    test(
      'an unverifiable indexed seek falls back to exact origin pictures ($diagnostic)',
      () async {
        final fixture = await sessionFixture(
          body:
              '''
if '-ss' in sys.argv:
    $diagnostic
sys.stdout.buffer.write(b''.join(bytes([index, 2, 3, 255]) for index in range(200)))''',
        );
        final session = await fixture.tools.openFrameSession(source, width: 1, height: 1);
        final frames = await session.readFrames([85]);
        expect(frames[85]!.rgba, [85, 2, 3, 255]);
        expect(session.decoderStarts, 2);
        expect(session.framesRead, 86);
      },
      skip: !native,
    );
  }

  test('a blocked indexed seek times out rather than assigning unverified ordinals', () async {
    final fixture = await sessionFixture(
      body: 'time.sleep(30)',
      timeout: const Duration(milliseconds: 100),
    );
    final session = await fixture.tools.openFrameSession(source, width: 1, height: 1);
    await expectLater(
      session.readFrames([85]),
      throwsA(
        isA<MediaProcessException>().having(
          (error) => error.message,
          'message',
          contains('Seeking'),
        ),
      ),
    );
    expect(
      Process.killPid(int.parse(await fixture.pid.readAsString()), ProcessSignal.sigcont),
      isFalse,
    );
  }, skip: !native);

  test(
    'duplicated keyframe timestamps decode from origin instead of guessing an ordinal',
    () async {
      final fixture = await sessionFixture(duplicateKeyTime: true);
      final session = await fixture.tools.openFrameSession(source, width: 1, height: 1);
      expect((await session.readFrames([85]))[85]!.rgba, [1, 2, 3, 255]);
      expect(session.decoderStarts, 1);
      expect(session.framesRead, 86);
    },
    skip: !native,
  );

  test('closing while a decoder starts settles both read and disposal', () async {
    final fixture = await sessionFixture(body: 'time.sleep(30)');
    final session = await fixture.tools.openFrameSession(source, width: 1, height: 1);
    final read = session.readFrames([0]);
    Future<void>? closed;
    scheduleMicrotask(() => closed = session.close());
    await expectLater(read, throwsStateError);
    await closed!.timeout(const Duration(seconds: 2));
    expect(session.decoderStarts, 0);
  }, skip: !native);
}
