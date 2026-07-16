import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

/// A deck with no ambient motion, so two captures at aligned clocks are
/// byte-comparable.
Video _deck() => Video(
  width: 320,
  height: 180,
  scenes: [
    Scene(
      duration: const Time.seconds(4),
      background: Background.color(const Color(0xFF14141C)),
      children: [
        const SizedBox(
          width: 100,
          height: 30,
          child: ColoredBox(color: Color(0xFFF2F2F7)),
        ).animate([Animation.fadeIn(duration: const Time.seconds(0.5))]),
        Stop.single(
          child: Align(
            alignment: const Alignment(0, 0.6),
            child: const SizedBox(
              width: 120,
              height: 40,
              child: ColoredBox(color: Color(0xFF6C5CE7)),
            ).animate([Animation.fadeIn(duration: const Time.seconds(1))]),
          ),
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets('the held state after back matches the forward-arrived state', (tester) async {
    final video = _deck();
    final container = ProviderContainer(
      overrides: [slidePlansProvider.overrideWithValue(compileSlidePlans(video))],
    );
    addTearDown(container.dispose);
    final clocks = <LivePlaybackController>[];
    final boundary = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Center(
          child: RepaintBoundary(
            key: boundary,
            child: SizedBox(
              width: 320,
              height: 180,
              child: SlideView(
                video: video,
                clockFactory: (fps) {
                  final clock = LivePlaybackController(fps: fps)..hold(45);
                  clocks.add(clock);
                  return clock;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    Future<List<int>> capture() async {
      final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      final bytes = await image.toByteData();
      image.dispose();
      return bytes!.buffer.asUint8List().toList();
    }

    final controller = container.read(presentationControllerProvider.notifier);

    // Forward: reveal at frame 45, then let the entrance settle (30 frames).
    // (Separate statements, not a cascade: the pumps between the calls are
    // the point of this test.)
    // ignore: cascade_invocations
    controller.next();
    await tester.pump();
    clocks.single.hold(75);
    await tester.pump();
    // toImage is real async: it must run outside the test's fake clock.
    final forwardArrived = await tester.runAsync(capture);

    // Back to step 0, then jump-land on step 1 as a held state.
    controller.back();
    await tester.pump();
    controller.jumpToStep(0, 1);
    await tester.pump();
    final heldState = await tester.runAsync(capture);

    expect(heldState, forwardArrived);
  });
}
