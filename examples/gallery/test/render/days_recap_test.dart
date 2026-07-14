import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/render/composition_registry.dart';
import 'package:fluvie_example/render/days_recap_composition.dart';

// Mounting the recap and seeking through it resolves its animation timing
// plan, so an invalid trigger or stagger fails here, not only at render time.
void main() {
  test('the days_recap entry is registered with its declared geometry', () {
    final entry = compositionForKey('days_recap');
    expect(entry, isNotNull);
    expect(entry!.width, 1280);
    expect(entry.height, 720);
    expect(entry.fps, 30);
    expect(entry.frameCount, daysRecapVideo().totalFrames);
    // Every photo and clip is declared so the harness pre-resolves it.
    expect(entry.mediaSources, isNotEmpty);
  });

  test('the recap spans an intro, one scene per day, and an outro', () {
    // Four days in the data set, wrapped by the intro and outro cards.
    expect(daysRecapVideo().scenes, hasLength(6));
  });

  testWidgets('the recap resolves its timeline and builds without error', (tester) async {
    final video = daysRecapVideo();
    final controller = RenderController();
    await tester.pumpWidget(
      RenderControllerScope(
        controller: controller,
        child: Directionality(textDirection: TextDirection.ltr, child: video),
      ),
    );

    for (final frame in [0, video.totalFrames ~/ 2, video.totalFrames - 1]) {
      controller.seek(frame);
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  });
}
