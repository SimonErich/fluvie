import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

void main() {
  test('the barrel exposes the presenter surface', () {
    // The barrel is the package's single public entry: the viewer and the
    // playback wrapper are reachable from it alone.
    final video = Video(scenes: const [Scene(duration: Time.seconds(1))]);
    expect(FluvieSlides(video), isA<FluvieSlides>());
    expect(LiveScenePlayer(video: video), isA<LiveScenePlayer>());
  });
}
