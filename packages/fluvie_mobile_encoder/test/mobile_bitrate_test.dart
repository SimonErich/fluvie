import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

void main() {
  test('scales with resolution and frame rate', () {
    expect(
      defaultBitRate(width: 1920, height: 1080, fps: 30),
      (1920 * 1080 * 30 * 0.1).round(),
    );
  });

  test('clamps up to the minimum floor for tiny clips', () {
    expect(defaultBitRate(width: 16, height: 16, fps: 1), 1000000);
  });

  test('rejects a non-positive width', () {
    expect(() => defaultBitRate(width: 0, height: 16, fps: 1), throwsArgumentError);
  });
  test('rejects a non-positive height', () {
    expect(() => defaultBitRate(width: 16, height: 0, fps: 1), throwsArgumentError);
  });
  test('rejects a non-positive fps', () {
    expect(() => defaultBitRate(width: 16, height: 16, fps: 0), throwsArgumentError);
  });
}
