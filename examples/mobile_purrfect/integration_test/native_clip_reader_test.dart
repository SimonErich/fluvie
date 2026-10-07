@Tags(['render'])
@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(MethodChannelMobileVideoEncoder.channelName);

  for (final name in ['fractional_rotated', 'variable_rate']) {
    testWidgets('native decoder preserves $name source ordinals and RGBA orientation', (
      tester,
    ) async {
      final directory = await Directory.systemTemp.createTemp('fluvie_clip_reader_');
      addTearDown(() => directory.delete(recursive: true));
      final data = await rootBundle.load('assets/acceptance/$name.mp4');
      final file = File('${directory.path}/fixture.mp4');
      await file.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      final oracle =
          jsonDecode(await rootBundle.loadString('assets/acceptance/$name.json'))
              as Map<String, Object?>;
      final sourceWidth = oracle['width']! as int;
      final sourceHeight = oracle['height']! as int;
      final width = sourceWidth ~/ 2;
      final height = sourceHeight ~/ 2;
      final count = oracle['frameCount']! as int;
      final facts = await channel.invokeMapMethod<String, Object?>('probeVideo', {
        'path': file.path,
      });
      expect(facts?['width'], sourceWidth);
      expect(facts?['height'], sourceHeight);
      expect(facts?['frameCount'], count);
      expect(facts?['hasAudio'], isFalse);
      expect(facts?['codec'], 'h264');
      if (oracle['fps'] case final num fps) {
        expect((facts?['fps'] as num?)?.toDouble(), closeTo(fps.toDouble(), 0.0001));
      }

      // Nonsequential requests and duplicates must retain caller order. The
      // fixtures contain B-frames; decode order differs from display order.
      final indices = [count - 1, ...List.generate(count, (index) => index).reversed, 0];
      final pixels = await channel.invokeMethod<Uint8List>('extractFrames', {
        'path': file.path,
        'indices': indices,
        'width': width,
        'height': height,
      });
      expect(pixels, hasLength(indices.length * width * height * 4));
      final corners = oracle['cornersRgb']! as List<Object?>;
      final positions = [
        (width ~/ 4, height ~/ 4),
        (3 * width ~/ 4, height ~/ 4),
        (width ~/ 4, 3 * height ~/ 4),
        (3 * width ~/ 4, 3 * height ~/ 4),
      ];
      for (var request = 0; request < indices.length; request++) {
        final expected = corners[indices[request]]! as List<Object?>;
        for (var corner = 0; corner < positions.length; corner++) {
          final (x, y) = positions[corner];
          final offset = (request * width * height + y * width + x) * 4;
          final rgb = expected[corner]! as List<Object?>;
          for (var component = 0; component < 3; component++) {
            expect(
              pixels![offset + component],
              closeTo((rgb[component]! as num).toDouble(), 18),
              reason: '$name source ${indices[request]}, corner $corner, channel $component',
            );
          }
          expect(pixels![offset + 3], 255);
        }
      }

      await expectLater(
        channel.invokeMethod<Uint8List>('extractFrames', {
          'path': file.path,
          'indices': [count],
          'width': width,
          'height': height,
        }),
        throwsA(isA<PlatformException>().having((error) => error.code, 'code', 'extract_failed')),
      );
      // A file may be re-imported or replaced at the same path. Its previous
      // presentation index and orientation must not remain in the native cache.
      final replacement = name == 'fractional_rotated' ? 'variable_rate' : 'fractional_rotated';
      final replacementData = await rootBundle.load('assets/acceptance/$replacement.mp4');
      await file.writeAsBytes(
        replacementData.buffer.asUint8List(
          replacementData.offsetInBytes,
          replacementData.lengthInBytes,
        ),
      );
      final replacementFacts = await channel.invokeMapMethod<String, Object?>('probeVideo', {
        'path': file.path,
      });
      expect(replacementFacts?['width'], sourceHeight);
      expect(replacementFacts?['height'], sourceWidth);
      expect(replacementFacts?['frameCount'], count == 12 ? 6 : 12);
    });
  }

  testWidgets('native decoder validates allocations before opening a clip', (tester) async {
    for (final values in [
      {
        'indices': [-1],
        'width': 16,
        'height': 16,
      },
      {
        'indices': [0],
        'width': 0,
        'height': 16,
      },
      {
        'indices': [0],
        'width': 1 << 62,
        'height': 16,
      },
    ]) {
      await expectLater(
        channel.invokeMethod<Uint8List>('extractFrames', {'path': '/missing.mp4', ...values}),
        throwsA(isA<PlatformException>().having((error) => error.code, 'code', 'bad_request')),
      );
    }
    await expectLater(
      channel.invokeMethod<Object?>('probeVideo', {'path': '/missing.mp4'}),
      throwsA(isA<PlatformException>().having((error) => error.code, 'code', 'probe_failed')),
    );
  });
}
