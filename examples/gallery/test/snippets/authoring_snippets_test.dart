import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/snippets/authoring_snippets.dart' as examples;

void main() {
  test('website promo has the published compact canvas and complete ten-second duration', () {
    final video = examples.promo();
    expect((video.width, video.height), (320, 320));
    expect(video.fps, 12);
    expect(video.totalFrames, 120);
    expect(video.poster, 3.seconds);
  });
}
