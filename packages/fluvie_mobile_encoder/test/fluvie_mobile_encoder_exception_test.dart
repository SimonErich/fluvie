import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

void main() {
  test('toString without a code', () {
    expect(
      const FluvieMobileEncoderException('it failed').toString(),
      'FluvieMobileEncoderException: it failed',
    );
  });

  test('toString with a platform code', () {
    expect(
      const FluvieMobileEncoderException('it failed', code: 'encode_failed').toString(),
      'FluvieMobileEncoderException(encode_failed): it failed',
    );
  });
}
