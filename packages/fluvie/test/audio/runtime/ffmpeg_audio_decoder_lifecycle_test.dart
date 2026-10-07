import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_media/fluvie_media.dart';

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('fluvie_pcm_lifecycle_');
  });
  tearDown(() async => sandbox.delete(recursive: true));

  Future<String> executable(String body) async {
    final script = File('${sandbox.path}/decoder.sh');
    await script.writeAsString('#!/bin/sh\n$body\n');
    expect((await Process.run('chmod', ['+x', script.path])).exitCode, 0);
    return script.path;
  }

  Future<int> startedPid() async {
    final file = File('${sandbox.path}/decoder.pid');
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!file.existsSync()) {
      if (DateTime.now().isAfter(deadline)) fail('Decoder did not start.');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return int.parse(file.readAsStringSync().trim());
  }

  Future<void> expectReaped(int pid) async {
    expect((await Process.run('kill', ['-0', '$pid'])).exitCode, isNot(0));
  }

  test('PCM cancellation kills and reaps a stalled decoder', () async {
    final binary = await executable(
      r'echo $$ > decoder.pid'
      '\nexec sleep 30',
    );
    final cancelled = Completer<void>();
    final decoder = FfmpegPcmDecoder(
      decoder: FfmpegAudioDecoder(binaryPath: binary),
      whenCancelled: cancelled.future,
    );
    final pending = decoder.decode(AudioSource.file('${sandbox.path}/source.wav'));
    final result = expectLater(pending, throwsA(isA<MediaCancelledException>()));
    final pid = await startedPid();
    cancelled.complete();
    await result.timeout(const Duration(seconds: 5));
    await expectReaped(pid);
  }, skip: Platform.isWindows);

  test('timeout kills and reaps a stalled decoder with source context', () async {
    final binary = await executable(
      r'echo $$ > decoder.pid'
      '\nexec sleep 30',
    );
    final pending = FfmpegAudioDecoder(
      binaryPath: binary,
      timeout: const Duration(milliseconds: 250),
    ).decode('source.wav', workingDirectory: sandbox.path);
    final result = expectLater(
      pending,
      throwsA(
        isA<FluvieRenderException>()
            .having((error) => error.toString(), 'diagnostic', contains('source.wav'))
            .having((error) => error.toString(), 'timeout', contains('timed out')),
      ),
    );
    final pid = await startedPid();
    await result;
    await expectReaped(pid);
  }, skip: Platform.isWindows);

  test('PCM sample limit bounds output before allocating the DSP buffer', () async {
    final binary = await executable('head -c 4096 /dev/zero');
    await expectLater(
      FfmpegAudioDecoder(
        binaryPath: binary,
        maxSamples: 8,
      ).decode('source.wav', workingDirectory: sandbox.path),
      throwsA(
        isA<FluvieRenderException>().having(
          (error) => error.toString(),
          'remedy',
          contains('maxSamples'),
        ),
      ),
    );
  }, skip: Platform.isWindows);

  test('preserves little-endian samples and rejects incomplete samples', () async {
    final binary = await executable(r"printf '\000\000\200\077\000\000\000\277'");
    final pcm = await FfmpegPcmDecoder(
      decoder: FfmpegAudioDecoder(binaryPath: binary),
    ).decode(AudioSource.file('${sandbox.path}/source.wav'));
    expect(pcm.samples, [1.0, -0.5]);
    expect(pcm.sampleRate, 44100);
    await executable("printf '123'");
    await expectLater(
      FfmpegAudioDecoder(binaryPath: binary).decode('source.wav', workingDirectory: sandbox.path),
      throwsA(
        isA<FluvieRenderException>().having(
          (error) => error.toString(),
          'diagnostic',
          contains('incomplete PCM sample'),
        ),
      ),
    );
  }, skip: Platform.isWindows);

  test('failed decoder retains bounded stderr and executable context', () async {
    final binary = await executable('head -c 32768 /dev/zero >&2\nexit 7');
    await expectLater(
      FfmpegAudioDecoder(binaryPath: binary).decode('source.wav', workingDirectory: sandbox.path),
      throwsA(
        isA<FluvieRenderException>()
            .having((error) => error.toString(), 'exit code', contains('exited 7'))
            .having((error) => error.toString().length, 'bounded message', lessThan(17000)),
      ),
    );
  }, skip: Platform.isWindows);

  test('pre-cancelled analysis does not start the decoder', () async {
    final binary = await executable(
      r'echo $$ > decoder.pid'
      '\nexec sleep 30',
    );
    await expectLater(
      FfmpegAudioDecoder(binaryPath: binary).decode(
        'source.wav',
        workingDirectory: sandbox.path,
        whenCancelled: Future<void>.value(),
      ),
      throwsA(isA<MediaCancelledException>()),
    );
    expect(File('${sandbox.path}/decoder.pid').existsSync(), isFalse);
  }, skip: Platform.isWindows);

  test('invalid bounds and unmaterialized sources fail before starting FFmpeg', () async {
    for (final decoder in [
      const FfmpegAudioDecoder(maxSamples: 0),
      const FfmpegAudioDecoder(timeout: Duration.zero),
    ]) {
      await expectLater(
        decoder.decode('source.wav', workingDirectory: sandbox.path),
        throwsArgumentError,
      );
    }
    await expectLater(
      const FfmpegPcmDecoder().decode(const AudioSource.asset('assets/source.wav')),
      throwsArgumentError,
    );
  });

  test(
    'absent decoder reports executable and source instead of leaking ProcessException',
    () async {
      await expectLater(
        FfmpegAudioDecoder(
          binaryPath: '${sandbox.path}/absent_decoder',
        ).decode('source.wav', workingDirectory: sandbox.path),
        throwsA(
          isA<FluvieRenderException>()
              .having((error) => error.toString(), 'executable', contains('absent_decoder'))
              .having((error) => error.toString(), 'source', contains('source.wav')),
        ),
      );
    },
  );
}
