@Tags(['render'])
@Timeout(Duration(minutes: 10))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Clip;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';
import 'package:integration_test/integration_test.dart';

/// Creates real platform exports; the host verifier independently decodes the
/// retained MP4s to check every video frame and the audible gain/speed envelope.
void main() {
  // The production offscreen host waits for composition post-frame setup.
  // Permit real engine frames while the test awaits the native render.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('native clip export preserves pixels, audio, automation and speed', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    const channel = MethodChannel(MethodChannelMobileVideoEncoder.channelName);
    final directory = Directory('${Directory.systemTemp.path}/fluvie_release_acceptance');
    await directory.create(recursive: true);
    final tone = File('${directory.path}/tone.wav');
    await tone.writeAsBytes(_tone());
    final outputs = <Map<String, Object?>>[];

    Future<File> render(Video video, String name, int frames, int longEdge) async {
      final sandbox = Directory('${directory.path}/${name}_sandbox');
      await sandbox.create(recursive: true);
      final output = File('${directory.path}/$name.mp4');
      final clock = Stopwatch()..start();
      final phaseMilliseconds = <String, int>{};
      await OnDeviceVideoRenderer(sandboxFactory: () async => sandbox).render(
        composition: video,
        aspect: Aspect.square,
        duration: Duration(microseconds: frames * Duration.microsecondsPerSecond ~/ 24),
        fps: 24,
        longEdge: longEdge,
        audio: true,
        bitRate: 1500000,
        outputFile: output,
        onProgress: (progress) =>
            phaseMilliseconds[progress.phase.name] = clock.elapsedMilliseconds,
      );
      final facts = await channel.invokeMapMethod<String, Object?>('probeVideo', {
        'path': output.path,
      });
      expect(facts?['hasAudio'], isTrue, reason: '$name must retain an AAC track');
      expect(facts?['frameCount'], frames);
      expect(facts?['durationMs'], frames * 1000 ~/ 24);
      expect((facts?['fps'] as num?)?.toDouble(), 24);
      expect(facts?['width'], longEdge);
      outputs.add({
        'name': name,
        'frames': frames,
        'size': longEdge,
        'probe': facts,
        'phaseMilliseconds': phaseMilliseconds,
      });
      return output;
    }

    await tester.runAsync(() async {
      final source = await render(
        Video(
          size: const VideoSize(160, 160),
          fps: 24,
          audio: [Audio.music(tone.path)],
          scenes: const [
            Scene(
              duration: Time.frames(48),
              children: [SizedBox.expand(child: ColoredBox(color: Color(0xFFEE0C0C)))],
            ),
            Scene(
              duration: Time.frames(48),
              children: [SizedBox.expand(child: ColoredBox(color: Color(0xFF0C0CEE)))],
            ),
          ],
        ),
        'source',
        96,
        160,
      );
      for (final size in [160, 128]) {
        final output = await render(
          Video(
            size: const VideoSize(160, 160),
            fps: 24,
            audio: [
              // Missing files prove the zero-sample guard runs before loading.
              Audio.music(
                '${directory.path}/missing-at-end.wav',
                at: const Trigger.at(Time.frames(72)),
              ),
              Audio.music(
                '${directory.path}/missing-after-end.wav',
                at: const Trigger.at(Time.frames(80)),
              ),
            ],
            scenes: [
              Scene(
                duration: const Time.frames(72),
                audio: [
                  Audio.music(
                    '${directory.path}/missing-scene-end.wav',
                    at: const Trigger.at(Time.frames(72)),
                  ),
                ],
                children: [
                  Clip.file(
                    source.path,
                    trim: const TimeRange(Time.seconds(0.25), Time.seconds(3.5)),
                    speedRamp: const KeyframedNumber(
                      values: [0.5, 1.5],
                      positions: [Time.zero, Time.frames(72)],
                      easings: [Ease.linear],
                    ),
                    audio: const ClipAudio.included(
                      fadeIn: Time.frames(6),
                      fadeOut: Time.frames(6),
                      automation: AudioAutomation(
                        values: [0.2, 0.8],
                        positions: [Time.zero, Time.frames(72)],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          'ramp_$size',
          72,
          size,
        );
        final pixels = await channel.invokeMethod<Uint8List>('extractFrames', {
          'path': output.path,
          'indices': [0, 24, 60, 71],
          'width': 16,
          'height': 16,
        });
        expect(pixels, hasLength(4 * 16 * 16 * 4));
        for (var index = 0; index < 4; index++) {
          final offset = (index * 16 * 16 + 8 * 16 + 8) * 4;
          final red = pixels![offset];
          final blue = pixels[offset + 2];
          expect(
            index < 2 ? red - blue : blue - red,
            greaterThan(180),
            reason: '$size export, probe index $index: red=$red blue=$blue',
          );
        }
      }
      await File('${directory.path}/device-report.json').writeAsString(
        const JsonEncoder.withIndent(
          '  ',
        ).convert({'platform': Platform.operatingSystem, 'outputs': outputs}),
      );
    });
  });
}

Uint8List _tone() {
  const rate = 44100;
  const count = rate * 4;
  final bytes = Uint8List(44 + count * 2);
  final data = ByteData.sublistView(bytes);
  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  data.setUint32(4, bytes.length - 8, Endian.little);
  bytes.setRange(8, 16, 'WAVEfmt '.codeUnits);
  data
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  bytes.setRange(36, 40, 'data'.codeUnits);
  data.setUint32(40, count * 2, Endian.little);
  for (var index = 0; index < count; index++) {
    data.setInt16(
      44 + index * 2,
      (0.4 * 32767 * math.sin(2 * math.pi * (index < rate * 2 ? 400 : 800) * index / rate)).round(),
      Endian.little,
    );
  }
  return bytes;
}
