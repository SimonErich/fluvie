@Tags(['ffmpeg'])
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';

void main() {
  test('native source seek decodes the requested samples within its buffer budget', () async {
    final root = await Directory.systemTemp.createTemp('fluvie_pcm_range_');
    addTearDown(() => root.delete(recursive: true));
    final binary = const FfmpegAudioDecoder().binaryPath;
    final result = await Process.run(binary, [
      '-hide_banner',
      '-loglevel',
      'error',
      '-f',
      'lavfi',
      '-i',
      r'aevalsrc=if(lt(t\,1)\,0.1\,0.6)*sin(2*PI*440*t):s=44100:d=3',
      '${root.path}/source.wav',
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final decoder = FfmpegPcmDecoder(
      decoder: FfmpegAudioDecoder(binaryPath: binary, maxSamples: 5000),
    );
    final source = AudioSource.file('${root.path}/source.wav');
    final pcm = await decoder.decodeRange(
      source,
      start: const Duration(milliseconds: 1200),
      duration: const Duration(milliseconds: 100),
    );
    expect(pcm.samples.length, inInclusiveRange(4409, 4411));
    final rms = sqrt(
      pcm.samples.fold<double>(0, (sum, sample) => sum + sample * sample) / pcm.samples.length,
    );
    expect(rms, closeTo(.6 / sqrt(2), .001));
    await expectLater(decoder.decode(source), throwsA(isA<FluvieRenderException>()));
  });
}
