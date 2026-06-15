import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';

/// Records every frame the probe builds with; the list length is the build
/// count, so rebuild behavior and frame values are asserted together.
class _FrameLog {
  final List<int> frames = [];
}

/// A leaf reading `FrameProvider.of(context).frame`, appending to [log] on
/// every build.
Widget _probe(_FrameLog log) => Builder(
  builder: (context) {
    log.frames.add(FrameProvider.of(context).frame);
    return const SizedBox.shrink();
  },
);

void main() {
  group('RenderControllerScope (epic 4.1 acceptance)', () {
    testWidgets('the probe sees exactly 0, 7, 42 across seeks', (tester) async {
      final controller = RenderController();
      addTearDown(controller.dispose);
      final log = _FrameLog();
      await tester.pumpWidget(RenderControllerScope(controller: controller, child: _probe(log)));

      controller.seek(7);
      await tester.pump();
      controller.seek(42);
      await tester.pump();

      expect(log.frames, [0, 7, 42]);
    });

    testWidgets('pumping without a seek does not rebuild the probe', (tester) async {
      final controller = RenderController();
      addTearDown(controller.dispose);
      final log = _FrameLog();
      await tester.pumpWidget(RenderControllerScope(controller: controller, child: _probe(log)));
      expect(log.frames, [0]);

      await tester.pump();
      await tester.pump();

      expect(log.frames, [0], reason: 'no seek happened, so the probe must not rebuild');

      controller.seek(7);
      await tester.pump();
      expect(log.frames, [0, 7], reason: 'a seek still reaches the probe afterwards');
    });

    testWidgets('two scopes with two controllers stay independent', (tester) async {
      final a = RenderController();
      final b = RenderController();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      final logA = _FrameLog();
      final logB = _FrameLog();
      await tester.pumpWidget(
        Column(
          children: [
            RenderControllerScope(controller: a, child: _probe(logA)),
            RenderControllerScope(controller: b, child: _probe(logB)),
          ],
        ),
      );

      a.seek(5);
      await tester.pump();
      expect(logA.frames, [0, 5]);
      expect(logB.frames, [0], reason: 'seeking A must not rebuild B');

      b.seek(9);
      await tester.pump();
      expect(logA.frames, [0, 5], reason: 'seeking B must not rebuild A');
      expect(logB.frames, [0, 9]);
    });

    testWidgets('swapping the controller rebinds the scope', (tester) async {
      final first = RenderController();
      final second = RenderController(initialFrame: 9);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final log = _FrameLog();
      await tester.pumpWidget(RenderControllerScope(controller: first, child: _probe(log)));
      first.seek(3);
      await tester.pump();
      expect(log.frames, [0, 3]);

      await tester.pumpWidget(RenderControllerScope(controller: second, child: _probe(log)));
      expect(log.frames, [0, 3, 9], reason: 'the swap exposes the new controller frame');

      first.seek(20);
      await tester.pump();
      expect(log.frames, [0, 3, 9], reason: 'the old controller is unbound after the swap');

      second.seek(11);
      await tester.pump();
      expect(log.frames, [0, 3, 9, 11], reason: 'the new controller drives the probe');
    });
  });
}
