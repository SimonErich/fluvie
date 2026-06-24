import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:web_server_studio/render/spec_builder.dart';

void main() {
  test('kittenPromoSpec builds a spec the server can parse and build', () {
    final json = kittenPromoSpec(
      headline: 'Hi',
      tagline: 'there',
    );

    final video = VideoSpec.fromJson(json).build();

    expect(video.scenes, hasLength(1));
    expect(video.totalFrames, greaterThan(0));
  });

  test('omits the tagline line when none is given but stays valid', () {
    final json = kittenPromoSpec(headline: 'Solo');

    expect(() => VideoSpec.fromJson(json).build(), returnsNormally);
  });
}
