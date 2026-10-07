@Tags(['ffmpeg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show AudioBand, AudioSource;
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/rendering/preparation_audio_io.dart';

final class _CountingDecoder implements PcmDecoder {
  int calls = 0;

  @override
  Future<PcmAudio> decode(AudioSource source) {
    calls++;
    return const FfmpegPcmDecoder().decode(source);
  }
}

void main() {
  group('FfmpegAudioDecoder (needs a real ffmpeg)', () {
    late Directory sandbox;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('fluvie_audio_decode_');
    });

    tearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    test('default preparation derives beats and bands from one native tone decode', () async {
      final executable = const FfmpegAudioDecoder().binaryPath;
      final tone = File('${sandbox.path}/tone.wav');
      final generated = await Process.run(executable, [
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=0.5',
        tone.path,
      ]);
      expect(generated.exitCode, 0, reason: '${generated.stderr}');
      final decoder = _CountingDecoder();
      final analysis = defaultPreparationAudio(decoder: decoder);
      final source = AudioSource.file(tone.path);
      try {
        await analysis.beats.detect(source, fps: 30, totalFrames: 15);
        final bands = await analysis.bands.analyze(source, fps: 30, totalFrames: 15);
        expect(decoder.calls, 1);
        expect(bands.totalFrames, 15);
        expect(bands.energyAt(0, AudioBand.mid), greaterThan(0));
        final defaults = defaultPreparationAudio();
        try {
          final defaultBands = await defaults.bands.analyze(source, fps: 30, totalFrames: 15);
          expect(defaultBands, bands);
        } finally {
          defaults.dispose();
        }
      } finally {
        analysis.dispose();
      }
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
