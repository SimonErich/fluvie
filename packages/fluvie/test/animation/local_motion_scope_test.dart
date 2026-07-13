import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/timing/schedule/composition_registrar_scope.dart';

/// Reports the opacity the animation pipeline hands its subtree by reading
/// the nearest FadeBox-driven paint is overkill; instead the probe simply
/// proves the element mounted and built without throwing.
class _Marker extends StatelessWidget {
  const _Marker();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 8, height: 8);
}

void main() {
  testWidgets('hides the enclosing composition registrar from descendants', (tester) async {
    late BuildContext inside;
    final video = Video(
      width: 320,
      height: 180,
      scenes: [
        Scene(
          duration: const Time.seconds(2),
          children: [
            LocalMotionScope(
              child: Builder(
                builder: (context) {
                  inside = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ],
    );
    final controller = LivePlaybackController(fps: 30);
    addTearDown(controller.dispose);
    await tester.pumpWidget(LivePlayer(controller: controller, child: video));
    expect(CompositionRegistrarScope.maybeOf(inside), isNull);
  });

  testWidgets('lets animated elements mount after the composition resolved', (tester) async {
    final reveal = ValueNotifier<bool>(false);
    addTearDown(reveal.dispose);
    final video = Video(
      width: 320,
      height: 180,
      scenes: [
        Scene(
          duration: const Time.seconds(2),
          children: [
            const Text('base', style: TextStyle(fontSize: 20)).animate([Animation.fadeIn()]),
            LocalMotionScope(
              child: ValueListenableBuilder<bool>(
                valueListenable: reveal,
                builder: (_, revealed, _) => revealed
                    ? const _Marker().animate([Animation.fadeIn()])
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ],
    );
    final controller = LivePlaybackController(fps: 30);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: LivePlayer(controller: controller, child: video),
      ),
    );
    // Let the composition collect and resolve its schedules.
    await tester.pump();
    await tester.pump();
    expect(find.byType(_Marker), findsNothing);

    // A fresh animated element after resolution: under the composition this
    // throws the late-registration timing error; inside the local scope it
    // resolves immediately.
    reveal.value = true;
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(_Marker), findsOneWidget);

    // And it unmounts freely too.
    reveal.value = false;
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(_Marker), findsNothing);
  });

  testWidgets('elements below it resolve locally against the nearest scope', (tester) async {
    // Outside any Video, standalone resolution is the documented fallback;
    // LocalMotionScope must keep exactly that behavior available under one.
    final controller = LivePlaybackController(fps: 30);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      LivePlayer(
        controller: controller,
        child: VideoScope(
          fps: 30,
          duration: const Time.seconds(2),
          child: LocalMotionScope(
            child: const _Marker().animate([Animation.fadeIn(duration: const Time.seconds(1))]),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(_Marker), findsOneWidget);
  });
}
