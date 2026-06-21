import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

void main() {
  test('each codec has a stable wire name', () {
    expect(MobileVideoCodec.h264.wireName, 'h264');
    expect(MobileVideoCodec.hevc.wireName, 'hevc');
  });
}
