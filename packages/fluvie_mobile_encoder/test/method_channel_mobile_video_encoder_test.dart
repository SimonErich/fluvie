import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(MethodChannelMobileVideoEncoder.channelName);
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  MobileEncodeRequest request() => MobileEncodeRequest(
    framesPath: '/tmp/frames.rgba',
    outputPath: '/tmp/out.mp4',
    width: 64,
    height: 64,
    fps: 30,
    frameCount: 3,
    bitRate: 1000000,
  );

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('invokes encode with the request arguments', () async {
    MethodCall? observed;
    messenger.setMockMethodCallHandler(channel, (call) async {
      observed = call;
      return null;
    });

    await const MethodChannelMobileVideoEncoder().encode(request());

    expect(observed!.method, MethodChannelMobileVideoEncoder.encodeMethod);
    final args = (observed!.arguments as Map).cast<String, Object?>();
    expect(args['framesPath'], '/tmp/frames.rgba');
    expect(args['outputPath'], '/tmp/out.mp4');
    expect(args['width'], 64);
    expect(args['height'], 64);
    expect(args['fps'], 30);
    expect(args['frameCount'], 3);
    expect(args['bitRate'], 1000000);
    expect(args['codec'], 'h264');
  });

  test('wraps a PlatformException as a FluvieMobileEncoderException', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'encode_failed', message: 'no encoder');
    });

    await expectLater(
      const MethodChannelMobileVideoEncoder().encode(request()),
      throwsA(
        isA<FluvieMobileEncoderException>()
            .having((e) => e.code, 'code', 'encode_failed')
            .having((e) => e.message, 'message', 'no encoder'),
      ),
    );
  });

  test('wraps a missing plugin as an unsupported-platform error', () async {
    messenger.setMockMethodCallHandler(channel, null);

    await expectLater(
      const MethodChannelMobileVideoEncoder().encode(request()),
      throwsA(
        isA<FluvieMobileEncoderException>().having((e) => e.code, 'code', 'unsupported_platform'),
      ),
    );
  });
}
