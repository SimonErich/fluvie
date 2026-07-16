import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:fluvie_presenter/src/sidebar/preview_render_host.dart';

void main() {
  testWidgets('the hidden host renders a slide to a thumbnail image', (tester) async {
    final video = Video(
      width: 320,
      height: 180,
      scenes: [
        Scene(
          duration: const Time.seconds(2),
          background: Background.color(const Color(0xFF223344)),
          children: const [Text('one', style: TextStyle(fontSize: 16))],
        ),
      ],
    );
    final hostKey = GlobalKey<PreviewRenderHostState>();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: PreviewRenderHost(
                key: hostKey,
                video: video,
                plans: compileSlidePlans(video),
              ),
            ),
          ],
        ),
      ),
    );
    // Idle host: nothing mounted.
    expect(find.byType(Video), findsNothing);

    final pending = hostKey.currentState!.render(0);
    // Drive the frames the host waits for (mount, resolve, settle).
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    // The toImage read-back completes on a real engine callback.
    final image = await tester.runAsync(() => pending);
    expect(image!.width, 320);
    expect(image.height, 180);
    await tester.pump();
    // The host went idle again.
    expect(find.byType(Video), findsNothing);
  });
}
