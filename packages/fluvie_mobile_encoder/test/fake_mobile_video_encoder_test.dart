import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

void main() {
  MobileEncodeRequest request(String outputPath) => MobileEncodeRequest(
    framesPath: '/f',
    outputPath: outputPath,
    width: 4,
    height: 4,
    fps: 30,
    frameCount: 1,
    bitRate: 1000000,
  );

  test('records the request and writes a placeholder output', () async {
    final dir = Directory.systemTemp.createTempSync('fake_enc_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final out = '${dir.path}/out.mp4';
    final encoder = FakeMobileVideoEncoder();

    final req = request(out);
    await encoder.encode(req);

    expect(encoder.requests.single, same(req));
    expect(File(out).existsSync(), isTrue);
  });

  test('throws the configured error and still records the request', () async {
    final encoder = FakeMobileVideoEncoder(
      throwOnEncode: const FluvieMobileEncoderException('boom'),
    );

    await expectLater(
      encoder.encode(request('/o')),
      throwsA(isA<FluvieMobileEncoderException>()),
    );
    expect(encoder.requests, hasLength(1));
  });
}
