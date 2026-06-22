import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart';

void main() {
  test('downloadBytes off the browser fails with a clear, file-naming error', () {
    expect(
      () => downloadBytes(Uint8List(0), filename: 'out.mp4'),
      throwsA(
        isA<UnsupportedError>().having((e) => e.message, 'message', contains('out.mp4')),
      ),
    );
  });
}
