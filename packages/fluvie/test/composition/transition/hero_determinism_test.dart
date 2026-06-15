import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/box.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/transition/runtime/morph_layer.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/core/video_size.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';

const _brand = Color(0xFF3498DB);

/// The §26-shaped hero composition (minus Image/Counter, which arrive in
/// Phase 8): a Box "logo" centred-large in scene 1, small top-left in scene 2,
/// morphing across an overlapping crossFade. A Text stands in for the Counter.
Video _heroVideo() {
  final logo = Anchor('logo');
  return Video(
    size: VideoSize.square,
    transition: Transition.crossFade(0.4.seconds), // overlap: window of 12 frames
    scenes: [
      Scene(
        duration: 2.seconds,
        children: [
          Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: SharedElement(
                anchor: logo,
                child: const Box(color: _brand),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Text('Intro', textDirection: TextDirection.ltr),
          ),
        ],
      ),
      Scene(
        duration: 2.seconds,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 40,
              height: 40,
              child: SharedElement(
                anchor: logo,
                child: const Box(color: _brand),
              ),
            ),
          ),
          // A self-contained animation on a non-shared element (warning-free).
          const Text('Stats', textDirection: TextDirection.ltr).animate([Animation.fadeIn()]),
        ],
      ),
    ],
  );
}

Widget _harness(Video video, RenderController controller) => RenderControllerScope(
  controller: controller,
  child: Directionality(textDirection: TextDirection.ltr, child: video),
);

void main() {
  group('Hero morph determinism + acceptance (WI-16)', () {
    testWidgets('the §26-shaped hero composition pumps warning-free', (tester) async {
      final controller = RenderController();
      await tester.pumpWidget(_harness(_heroVideo(), controller));
      await tester.pumpAndSettle();
      // 2s + 2s @30 with a 0.4s (12f) overlap: starts [0, 48], window [48, 60),
      // total 108. Walk the whole timeline including the blend; no exception.
      for (final frame in [0, 30, 47, 48, 53, 59, 60, 90, 107]) {
        controller.seek(frame);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'frame $frame threw');
      }
    });

    testWidgets('a blend-window frame reproduces its morph transform byte-for-byte', (
      tester,
    ) async {
      final controller = RenderController();
      await tester.pumpWidget(_harness(_heroVideo(), controller));
      await tester.pumpAndSettle();

      // 2s + 2s @30 with a 0.4s (12f) overlap: window [48, 60). Mid = 53.
      controller.seek(53);
      await tester.pump();
      final first = tester.renderObject<RenderMorphLayer>(find.byType(MorphLayer));
      final firstRect = first.morphRect;
      final firstOpacity = first.morphOpacity;

      // Seek away and back: the morph reproduces exactly (the frame is the
      // only clock — rects are read live, never time-dependent state).
      controller.seek(0);
      await tester.pump();
      controller.seek(53);
      await tester.pump();
      final second = tester.renderObject<RenderMorphLayer>(find.byType(MorphLayer));
      expect(second.morphRect, firstRect);
      expect(second.morphOpacity, firstOpacity);
    });

    testWidgets('two independent mounts agree on the morph transform', (tester) async {
      Future<({Rect rect, double opacity})> morphAt(int frame) async {
        final controller = RenderController(initialFrame: frame);
        await tester.pumpWidget(_harness(_heroVideo(), controller));
        await tester.pumpAndSettle();
        final morph = tester.renderObject<RenderMorphLayer>(find.byType(MorphLayer));
        return (rect: morph.morphRect, opacity: morph.morphOpacity);
      }

      final a = await morphAt(53);
      await tester.pumpWidget(const SizedBox());
      final b = await morphAt(53);
      expect(a.rect, b.rect);
      expect(a.opacity, b.opacity);
    });
  });
}
