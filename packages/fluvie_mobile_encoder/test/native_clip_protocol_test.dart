import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluvie/mobile_encoder');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'iOS clip protocol preserves portrait size, fractional fps and requested RGBA order',
    () async {
      final requests = <MethodCall>[];
      final payload = Uint8List.fromList([
        // Last source frame, then first, then last again. Each 2x4 frame has
        // different upper/lower rows and separate red/green/blue channels.
        for (final index in [11, 0, 11])
          for (var pixel = 0; pixel < 8; pixel++) ...[index, pixel * 10, 200, 255],
      ]);
      messenger.setMockMethodCallHandler(channel, (call) async {
        requests.add(call);
        if (call.method == 'probeVideo') {
          return {
            'width': 32,
            'height': 64,
            'frameCount': 12,
            'durationMs': 421,
            'fps': 30000 / 1001,
            'codec': 'h264',
            'hasAudio': true,
          };
        }
        return payload;
      });

      final facts = await const NativeVideoProbeService(channel, 4).probe('/clip.mov');
      expect((facts.width, facts.height), (2, 4));
      expect(facts.fps, 30000 / 1001);
      expect(facts.hasAudio, isTrue);
      expect(facts.nbFrames, 12);
      final frames = await const NativeFrameExtractionService().extractFrames(
        Uri.file('/clip.mov'),
        [11, 0, 11],
        width: facts.width,
        height: facts.height,
      );

      expect(requests.map((call) => call.method), ['probeVideo', 'extractFrames']);
      expect(requests.last.arguments, {
        'path': '/clip.mov',
        'indices': [11, 0, 11],
        'width': 2,
        'height': 4,
      });
      expect(frames.keys, [11, 0]);
      expect(frames[11]!.rgba.sublist(0, 4), [11, 0, 200, 255]);
      expect(frames[0]!.rgba.sublist(28, 32), [0, 70, 200, 255]);
      // Frames own their storage; a channel buffer must not remain aliased.
      payload.fillRange(0, payload.length, 0);
      expect(frames[11]!.rgba.sublist(0, 4), [11, 0, 200, 255]);
    },
  );

  test('an overlong native batch is rejected instead of hiding an extra decoded frame', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => Uint8List(2 * 2 * 4 + 4));
    await expectLater(
      const NativeFrameExtractionService().extractFrame(
        Uri.file('/clip.mov'),
        0,
        width: 2,
        height: 2,
      ),
      throwsA(
        isA<FluvieMobileEncoderException>().having((error) => error.code, 'code', 'extract_failed'),
      ),
    );
  });
}
