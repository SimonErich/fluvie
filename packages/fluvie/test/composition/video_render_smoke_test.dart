import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/rendering/primitives/fade_box.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

void main() {
  group('Video — capture-mode render smoke (WI-8)', () {
    testWidgets('a single-scene fade shows the expected opacity per frame', (tester) async {
      // The local-fallback path through the real scopes: no registrar exists
      // yet (Epic 6.2), so MotionTarget resolves its own schedule against the
      // SceneScope that Video mounted.
      final controller = RenderController();
      await tester.pumpWidget(
        RenderModeContext(
          mode: RenderMode.capture,
          child: RenderControllerScope(
            controller: controller,
            child: Video(
              scenes: [
                Scene(
                  duration: 60.frames,
                  children: [
                    const SizedBox(width: 20, height: 20).animate([
                      Animation.from(
                        const Keyframe(opacity: 0),
                        duration: const Time.frames(20),
                        ease: Ease.linear,
                      ),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      Future<double> opacityAt(int frame) async {
        controller.seek(frame);
        await tester.pump();
        // FadeBox replaced the raw Opacity (D16-P6); it stays mounted at 1.0.
        return tester.widget<FadeBox>(find.byType(FadeBox)).opacity;
      }

      expect(await opacityAt(0), 0.0);
      expect(await opacityAt(10), closeTo(0.5, 1e-9));
      expect(await opacityAt(20), 1.0);
    });
  });
}
