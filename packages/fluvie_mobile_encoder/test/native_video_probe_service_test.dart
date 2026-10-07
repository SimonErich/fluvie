import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.fluvie/mobile_encoder');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('probe preserves exact native presentation timestamps when available', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => <String, Object?>{
        'width': 32,
        'height': 32,
        'frameCount': 3,
        'durationUs': 1000000,
        'fps': 3,
        'timeline': {
          'schemaVersion': 1,
          'presentationTimesUs': [0, 100000, 600000],
          'durationUs': 1000000,
        },
      },
    );
    final result = await const NativeVideoProbeService().probe('/cat.mp4');
    expect(result.timeline!.timeForFrame(2), 0.6);
    expect(result.timeline!.frameAt(0.5), 1);
  });

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
    expect(result.hasAudio, isFalse);
  });

  test('preserves embedded audio and declared fps across an audio tail', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => <String, Object?>{
        'width': 160,
        'height': 160,
        'frameCount': 96,
        'durationMs': 4047,
        'fps': 24.0,
        'hasAudio': true,
      },
    );

    final result = await const NativeVideoProbeService().probe('/clips/with-audio.mp4');
    expect(result.hasAudio, isTrue);
    expect(result.fps, 24);
  });

  test('preserves fractional video duration when the native track reports microseconds', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => <String, Object?>{
        'frameCount': 12,
        'durationMs': 400,
        'durationUs': 400400,
        'fps': 30000 / 1001,
      },
    );
    final result = await const NativeVideoProbeService().probe('/clips/ntsc.mp4');
    expect(result.durationSeconds, 0.4004);
    expect(result.fps, closeTo(30000 / 1001, 0.000001));
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
    // No mock handler registered: the platform method is unavailable.
    await expectLater(
      () => const NativeVideoProbeService().probe('/clips/a.mp4'),
      throwsA(
        isA<FluvieMobileEncoderException>().having((e) => e.code, 'code', 'unimplemented'),
      ),
    );
  });
}
