import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

void main() {
  test('the render phases run capturing then encoding then complete', () {
    expect(OnDeviceRenderPhase.values, [
      OnDeviceRenderPhase.capturing,
      OnDeviceRenderPhase.encoding,
      OnDeviceRenderPhase.complete,
    ]);
  });
}
