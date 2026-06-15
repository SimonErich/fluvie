@Tags(['ffmpeg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/runtime/ffmpeg_audio_decoder.dart';

void main() {
  group('FfmpegAudioDecoder (needs a real ffmpeg)', () {
    late Directory sandbox;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('fluvie_audio_decode_');
    });

    tearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    test('decodes a generated tone to non-empty mono PCM', () async {
      // Generate a short sine tone into the sandbox with ffmpeg itself.
      final gen = await Process.run('ffmpeg', [
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=0.5',
        '-ar',
        '44100',
        '-ac',
        '1',
        'tone.wav',
      ], workingDirectory: sandbox.path);
      expect(gen.exitCode, 0, reason: gen.stderr.toString());

      final samples = await const FfmpegAudioDecoder().decode(
        'tone.wav',
        workingDirectory: sandbox.path,
      );
      // 0.5s at 44100 Hz mono is ~22050 samples; allow for codec priming.
      expect(samples.length, greaterThan(20000));
      expect(samples.any((s) => s != 0), isTrue);
    });
  });
}
