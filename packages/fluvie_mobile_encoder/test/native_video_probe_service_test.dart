import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';
import 'package:fluvie_mobile_encoder/src/native_video_probe_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.fluvie/mobile_encoder');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('probe maps the platform facts into a VideoProbeResult', () async {
    MethodCall? observed;
    messenger.setMockMethodCallHandler(channel, (call) async {
      observed = call;
      return <String, Object?>{
        'codec': 'hevc',
        'width': 1280,
        'height': 720,
        'frameCount': 150,
        'durationMs': 5000,
      };
    });

    final result = await const NativeVideoProbeService().probe('/clips/a.mp4');

    expect(observed!.method, 'probeVideo');
    expect((observed!.arguments as Map)['path'], '/clips/a.mp4');
    expect(result.codec, 'hevc');
    expect(result.width, 1280);
    expect(result.height, 720);
    expect(result.nbFrames, 150);
    expect(result.durationSeconds, 5.0);
  });

  test('probe falls back to defaults when the facts omit fields', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => <String, Object?>{});

    final result = await const NativeVideoProbeService().probe('/clips/a.mp4');

    expect(result.codec, 'h264');
    expect(result.width, 0);
    expect(result.height, 0);
    expect(result.nbFrames, 0);
    expect(result.durationSeconds, 0.0);
  });

  test('probe caps an oversized clip to the long-edge bound', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => <String, Object?>{'width': 3840, 'height': 2160},
    );

    final result = await const NativeVideoProbeService().probe('/clips/4k.mp4');

    expect(result.width, 1920);
    expect(result.height, 1080);
  });

  test('probe rounds scaled dimensions down to even numbers (min 2)', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => <String, Object?>{'width': 1000, 'height': 1},
    );

    // maxLongEdge 4 forces a heavy down-scale: 1000 -> 4 (even), 1 -> 0 -> min 2.
    final result = await const NativeVideoProbeService(channel, 4).probe('/clips/odd.mp4');

    expect(result.width, 4);
    expect(result.height, 2);
  });

  test('probe wraps a PlatformException as a FluvieMobileEncoderException', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'probe_failed', message: 'unreadable');
    });

    await expectLater(
      const NativeVideoProbeService().probe('/clips/a.mp4'),
      throwsA(
        isA<FluvieMobileEncoderException>()
            .having((e) => e.code, 'code', 'probe_failed')
            .having((e) => e.message, 'message', 'unreadable'),
      ),
    );
  });

  test('probe rejects null platform facts', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);

    await expectLater(
      const NativeVideoProbeService().probe('/clips/a.mp4'),
      throwsA(
        isA<FluvieMobileEncoderException>().having((e) => e.code, 'code', 'probe_failed'),
      ),
    );
  });
  test('probe maps a missing platform implementation to a typed error', () async {
    // No mock handler registered: the method is unimplemented, as on iOS.
    await expectLater(
      () => const NativeVideoProbeService().probe('/clips/a.mp4'),
      throwsA(
        isA<FluvieMobileEncoderException>().having((e) => e.code, 'code', 'unimplemented'),
      ),
    );
  });
}
