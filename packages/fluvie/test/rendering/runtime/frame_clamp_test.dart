import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/rendering/runtime/frame_clamp.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';

/// Records the frame it sees and how often it builds.
final class _FrameProbe extends StatelessWidget {
  const _FrameProbe(this.frames);

  final List<int> frames;

  @override
  Widget build(BuildContext context) {
    frames.add(FrameProvider.of(context).frame);
    return const SizedBox(width: 5, height: 5);
  }
}

void main() {
  group('FrameClamp (D10)', () {
    Widget harness(RenderController controller, List<int> frames) => RenderControllerScope(
      controller: controller,
      child: FrameClamp(holdFrame: 10, child: _FrameProbe(frames)),
    );

    testWidgets('below the hold, frames pass through unchanged', (tester) async {
      final frames = <int>[];
      final controller = RenderController(initialFrame: 3);
      await tester.pumpWidget(harness(controller, frames));
      controller.seek(7);
      await tester.pump();

      expect(frames, [3, 7]);
    });

    testWidgets('past the hold, the child sees min(frame, holdFrame)', (tester) async {
      final frames = <int>[];
      final controller = RenderController(initialFrame: 25);
      await tester.pumpWidget(harness(controller, frames));

      expect(frames, [10]);
    });

    testWidgets('advancing past the hold never rebuilds the held child', (tester) async {
      final frames = <int>[];
      final controller = RenderController(initialFrame: 10);
      await tester.pumpWidget(harness(controller, frames));
      expect(frames, [10]);

      controller.seek(11);
      await tester.pump();
      controller.seek(20);
      await tester.pump();
      controller.seek(99);
      await tester.pump();

      // The clamped provider republishes the same frame, so its
      // updateShouldNotify stays false and the child never rebuilds.
      expect(frames, [10]);
    });

    testWidgets('crossing the hold from below rebuilds exactly once, at the hold frame', (
      tester,
    ) async {
      final frames = <int>[];
      final controller = RenderController(initialFrame: 9);
      await tester.pumpWidget(harness(controller, frames));
      controller.seek(12);
      await tester.pump();

      expect(frames, [9, 10]);
    });

    testWidgets('throws the FrameProvider error without a provider above', (tester) async {
      await tester.pumpWidget(const FrameClamp(holdFrame: 5, child: SizedBox()));

      expect(tester.takeException(), isA<FluvieTimingError>());
    });
  });
}
