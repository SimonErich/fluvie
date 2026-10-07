import 'package:flutter/widgets.dart' hide Animation, Clip, Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/rendering/primitives/fade_box.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

void main() {
  for (final overlay in [false, true]) {
    testWidgets('nested window paint and introspection agree (overlay=$overlay)', (tester) async {
      const key = ValueKey('nested');
      final inner = const SizedBox(key: key, width: 20, height: 20).animate(
        [Animation.fadeIn(duration: const Time.frames(20), ease: Ease.linear)],
        window: const TimeRange(Time.frames(10), Time.frames(90)),
      );
      final group = Column(children: [inner]).show(
        from: const Time.frames(20),
        to: const Time.frames(120),
      );
      final video = Video(
        scenes: [
          if (!overlay) const Scene(duration: Time.frames(60)),
          Scene(duration: const Time.frames(150), children: overlay ? const [] : [group]),
        ],
        overlays: overlay ? [group] : const [],
      );
      final origin = overlay ? 0 : 60;
      final element = introspectTimeline(video).elementForKey(key)!;
      expect(element.window, FrameSpan(origin + 30, origin + 110));
      expect(element.enterSpan, FrameSpan(origin + 30, origin + 50));
      final clock = RenderController(initialFrame: origin + 40);
      addTearDown(clock.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RenderControllerScope(controller: clock, child: video),
        ),
      );
      await tester.pump();
      final leafContext = tester.element(find.byKey(key));
      final paintedScope = TimeScopeProvider.of(leafContext);
      expect(paintedScope.startFrame, element.window.start);
      expect(paintedScope.endFrame, element.window.end);
      final fades = tester.widgetList<FadeBox>(
        find.ancestor(of: find.byKey(key), matching: find.byType(FadeBox)),
      );
      expect(fades.any((fade) => (fade.opacity - 0.5).abs() < 1e-6), isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
