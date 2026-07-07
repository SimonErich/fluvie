import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';
import 'package:fluvie_mobile_encoder/src/native_frame_extraction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.fluvie/mobile_encoder');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const service = NativeFrameExtractionService();
  final source = Uri.file('/clips/clip.mp4');

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  // A row-major RGBA buffer for the given frame [markers]: every byte of a frame
  // is set to that frame's marker, so a decoded slice is trivially verifiable.
  Uint8List rgbaFor(List<int> markers, int width, int height) {
    final frameBytes = width * height * 4;
    final out = Uint8List(markers.length * frameBytes);
    for (var i = 0; i < markers.length; i++) {
      out.fillRange(i * frameBytes, (i + 1) * frameBytes, markers[i] & 0xFF);
    }
    return out;
  }

  test('extractFrames returns nothing and skips the channel for no indices', () async {
    var called = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      called = true;
      return null;
    });

    final frames = await service.extractFrames(source, const [], width: 2, height: 2);

    expect(frames, isEmpty);
    expect(called, isFalse);
  });

  test('extractFrames decodes one platform batch into per-index RawFrames', () async {
    MethodCall? observed;
    messenger.setMockMethodCallHandler(channel, (call) async {
      observed = call;
      return rgbaFor([7, 9], 2, 2);
    });

    final frames = await service.extractFrames(source, [7, 9], width: 2, height: 2);

    expect(observed!.method, 'extractFrames');
    final args = (observed!.arguments as Map).cast<String, Object?>();
    expect(args['path'], '/clips/clip.mp4');
    expect(args['indices'], [7, 9]);
    expect(args['width'], 2);
    expect(args['height'], 2);

    expect(frames.keys.toList(), [7, 9]);
    expect(frames[7]!.frameIndex, 7);
    expect(frames[7]!.width, 2);
    expect(frames[7]!.height, 2);
    expect(frames[7]!.rgba.length, 2 * 2 * 4);
    expect(frames[7]!.rgba, everyElement(7));
    expect(frames[9]!.rgba, everyElement(9));
  });

  test('extractFrames chunks a large request into 8-frame platform calls', () async {
    final calls = <List<int>>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      final indices = ((call.arguments as Map)['indices'] as List).cast<int>();
      calls.add(indices);
      return rgbaFor(indices, 1, 1);
    });

    final frames = await service.extractFrames(
      source,
      List.generate(10, (i) => i),
      width: 1,
      height: 1,
    );

    expect(calls.map((c) => c.length).toList(), [8, 2]);
    expect(frames.length, 10);
    expect(frames[0]!.rgba, everyElement(0));
    expect(frames[9]!.rgba, everyElement(9));
  });

  test('extractFrames wraps a PlatformException as a FluvieMobileEncoderException', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'decode_failed', message: 'no decoder');
    });

    await expectLater(
      service.extractFrames(source, [0], width: 2, height: 2),
      throwsA(
        isA<FluvieMobileEncoderException>()
            .having((e) => e.code, 'code', 'decode_failed')
            .having((e) => e.message, 'message', 'no decoder'),
      ),
    );
  });

  test('extractFrames rejects a short platform buffer', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => Uint8List(3));

    await expectLater(
      service.extractFrames(source, [0], width: 2, height: 2),
      throwsA(
        isA<FluvieMobileEncoderException>().having((e) => e.code, 'code', 'extract_failed'),
      ),
    );
  });

  test('extractFrames rejects a null platform buffer', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);

    await expectLater(
      service.extractFrames(source, [0], width: 2, height: 2),
      throwsA(
        isA<FluvieMobileEncoderException>().having((e) => e.code, 'code', 'extract_failed'),
      ),
    );
  });

  test('extractFrame returns the single decoded frame', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => rgbaFor([4], 2, 2));

    final frame = await service.extractFrame(source, 4, width: 2, height: 2);

    expect(frame.frameIndex, 4);
    expect(frame.rgba, everyElement(4));
  });
  test('extractFrames maps a missing platform implementation to a typed error', () async {
    // No mock handler registered: the method is unimplemented, as on iOS.
    await expectLater(
      () => service.extractFrames(source, [0], width: 4, height: 4),
      throwsA(
        isA<FluvieMobileEncoderException>().having((e) => e.code, 'code', 'unimplemented'),
      ),
    );
  });
}
