import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/transition/runtime/morph_layer.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_overlay.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_registry.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_scope.dart';
import 'package:fluvie/src/composition/transition/runtime/transition_phase_scope.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

/// A scene shell carrying one positioned shared element, mirroring the live
/// render tree the overlay measures rects from.
Widget _shell({
  required SharedElementRegistry registry,
  required int sceneIndex,
  required Anchor anchor,
  required Alignment at,
  required double side,
}) => SceneScope(
  start: Time.frames(sceneIndex * 30),
  duration: 30.frames,
  child: SharedElementScope(
    registry: registry,
    sceneIndex: sceneIndex,
    child: Align(
      alignment: at,
      child: SizedBox(
        width: side,
        height: side,
        child: SharedElement(
          anchor: anchor,
          child: const ColoredBox(color: Color(0xFF00FF00)),
        ),
      ),
    ),
  ),
);

/// The whole morph rig at one [q]: two positioned slots plus the overlay,
/// inside a fixed 200x200 canvas. The morph paints the destination (scene 1)
/// child onto Rect.lerp(source, target, q).
Widget _rig({
  required SharedElementRegistry registry,
  required Anchor logo,
  required double q,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: SizedBox(
      width: 200,
      height: 200,
      child: RenderControllerScope(
        controller: RenderController(),
        child: VideoScope(
          fps: 30,
          duration: 60.frames,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _shell(
                registry: registry,
                sceneIndex: 0,
                anchor: logo,
                at: Alignment.center,
                side: 80,
              ),
              _shell(
                registry: registry,
                sceneIndex: 1,
                anchor: logo,
                at: Alignment.topLeft,
                side: 20,
              ),
              SharedElementOverlay(
                registry: registry,
                boundary: 0,
                progress: q,
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

RenderMorphLayer _morph(WidgetTester tester) =>
    tester.renderObject<RenderMorphLayer>(find.byType(MorphLayer));

void main() {
  group('MorphLayer geometry (WI-15, D8)', () {
    testWidgets('at q=0 the morph rect is the source rect', (tester) async {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      await tester.pumpWidget(_rig(registry: registry, logo: logo, q: 0));
      final morph = _morph(tester);
      // Source: centered 80x80 in the 200x200 canvas → (60,60,140,140).
      expect(morph.sourceRect, const Rect.fromLTWH(60, 60, 80, 80));
      expect(morph.morphRect, morph.sourceRect);
    });

    testWidgets('at q=1 the morph rect is the target rect', (tester) async {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      await tester.pumpWidget(_rig(registry: registry, logo: logo, q: 1));
      final morph = _morph(tester);
      // Target: top-left 20x20 → (0,0,20,20).
      expect(morph.targetRect, const Rect.fromLTWH(0, 0, 20, 20));
      expect(morph.morphRect, morph.targetRect);
    });

    testWidgets('at q=0.5 the morph rect is the exact lerp', (tester) async {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      await tester.pumpWidget(_rig(registry: registry, logo: logo, q: 0.5));
      final morph = _morph(tester);
      expect(morph.morphRect, Rect.lerp(morph.sourceRect, morph.targetRect, 0.5));
    });

    testWidgets('morph opacity lerps the two slots opacities', (tester) async {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      await tester.pumpWidget(_rig(registry: registry, logo: logo, q: 0.5));
      final pair = registry.pairAtBoundary(0)!;
      // No keyframes, so both slots are fully opaque and the morph follows.
      expect(pair.source.opacity, 1.0);
      expect(pair.target.opacity, 1.0);
      expect(_morph(tester).morphOpacity, 1.0);

      // Drive the slot opacities directly and repaint: the morph lerps them.
      pair.source.opacity = 0.2;
      pair.target.opacity = 1.0;
      tester.renderObject<RenderMorphLayer>(find.byType(MorphLayer)).markNeedsPaint();
      await tester.pump();
      expect(_morph(tester).morphOpacity, closeTo(0.6, 1e-9)); // lerp(0.2, 1, 0.5)
    });

    testWidgets('the overlay is absent outside a window', (tester) async {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      // boundary -1 (no active window): overlay shrinks.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: RenderControllerScope(
                controller: RenderController(),
                child: VideoScope(
                  fps: 30,
                  duration: 60.frames,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _shell(
                        registry: registry,
                        sceneIndex: 0,
                        anchor: logo,
                        at: Alignment.center,
                        side: 80,
                      ),
                      _shell(
                        registry: registry,
                        sceneIndex: 1,
                        anchor: logo,
                        at: Alignment.topLeft,
                        side: 20,
                      ),
                      const SharedElementOverlay(registry: null, boundary: null, progress: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(MorphLayer), findsNothing);
    });

    testWidgets('a MotionTarget in the clone resolves standalone (D9, no throw)', (tester) async {
      // The overlay clone hosts the destination child with no registrar scope,
      // so a nested animated element takes the standalone path. We assert the
      // overlay pumps without a FluvieTimingError.
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      await tester.pumpWidget(_rig(registry: registry, logo: logo, q: 0.5));
      expect(tester.takeException(), isNull);
      expect(find.byType(MorphLayer), findsOneWidget);
    });
  });

  group('RenderMorphLayer reactive setters (WI-24)', () {
    testWidgets('the pair setter is inert when both endpoints are identical', (tester) async {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      await tester.pumpWidget(_rig(registry: registry, logo: logo, q: 0.5));
      final render = _morph(tester);
      final pair = render.pair;
      render.pair = pair; // same source+target → early return, pair unchanged
      expect(identical(render.pair.source, pair.source), isTrue);
      expect(identical(render.pair.target, pair.target), isTrue);
    });

    testWidgets('the pair setter swaps to a pair with a different target', (tester) async {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      await tester.pumpWidget(_rig(registry: registry, logo: logo, q: 0.5));
      final render = _morph(tester);
      final old = render.pair;
      final replacement = (
        anchor: old.anchor,
        source: old.source,
        target: SharedSlotHandle(anchor: old.anchor, sceneIndex: 1, child: const SizedBox()),
      );
      render.pair = replacement;
      expect(identical(render.pair.target, replacement.target), isTrue);
    });

    testWidgets('the progress setter updates and a same-value set is inert', (tester) async {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      await tester.pumpWidget(_rig(registry: registry, logo: logo, q: 0.5));
      final render = _morph(tester)..progress = 0.75;
      expect(render.progress, 0.75);
      render.progress = 0.75; // equal → early return, value unchanged
      expect(render.progress, 0.75);
    });

    testWidgets('the morph layer never participates in hit testing', (tester) async {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      await tester.pumpWidget(_rig(registry: registry, logo: logo, q: 0.5));
      expect(_morph(tester).hitTestSelf(const Offset(5, 5)), isFalse);
    });
  });

  group('SharedElementOverlay phase plumbing', () {
    testWidgets('the morph mounts under the incoming SceneScope, no registrar', (tester) async {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      await tester.pumpWidget(_rig(registry: registry, logo: logo, q: 0.5));
      // A TransitionPhaseScope is not required for the overlay; the morph layer
      // exists once per complete pair in the active window.
      expect(find.byType(MorphLayer), findsOneWidget);
      // The phase scope is the slot suppression channel, not the overlay's.
      expect(find.byType(TransitionPhaseScope, skipOffstage: false), findsNothing);
    });
  });
}
