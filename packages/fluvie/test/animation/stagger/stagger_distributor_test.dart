import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/rendering/primitives/fade_box.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

/// Mounts [child] under the full frame + timing harness at [frame]:
/// a 60-frame, 30 fps video with one whole-length scene.
Widget _harness({required int frame, required Widget child}) => RenderControllerScope(
  controller: RenderController(initialFrame: frame),
  child: VideoScope(
    fps: 30,
    duration: const Time.frames(60),
    child: SceneScope(duration: const Time.frames(60), child: child),
  ),
);

Widget _square(String name) => SizedBox(
  key: ValueKey(name),
  width: 20,
  height: 20,
  child: const ColoredBox(color: Color(0xFF445566)),
);

/// The opacity applied to one child: its nearest [FadeBox] ancestor (the
/// primitive that replaced the raw Opacity, D16-P6 — mounted at 1.0 too).
double _opacityOver(WidgetTester tester, String name) => tester
    .widget<FadeBox>(
      find.ancestor(of: find.byKey(ValueKey(name)), matching: find.byType(FadeBox)).first,
    )
    .opacity;

void main() {
  group('stagger distribution (D13/D19) — staggered animations go per child', () {
    testWidgets('a staggered slideFadeIn cascades: child 0 leads, child 2 trails', (tester) async {
      await tester.pumpWidget(
        _harness(
          frame: 8,
          child:
              Column(
                children: [_square('a'), _square('b'), _square('c')],
              ).animate([
                Animation.slideFadeIn(
                  stagger: const Stagger.each(Time.frames(4)),
                  duration: const Time.frames(20),
                  ease: Ease.linear,
                ),
              ]),
        ),
      );
      // Spans 0..20 / 4..24 / 8..28 at frame 8 → linear progress 0.4/0.2/0.
      expect(_opacityOver(tester, 'a'), closeTo(0.4, 1e-9));
      expect(_opacityOver(tester, 'b'), closeTo(0.2, 1e-9));
      expect(_opacityOver(tester, 'c'), closeTo(0.0, 1e-9));
    });

    testWidgets('a non-staggered animation on a multi-child target wraps the container', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          frame: 10,
          child: Column(
            children: [_square('a'), _square('b')],
          ).animate([Animation.fadeIn(duration: const Time.frames(20), ease: Ease.linear)]),
        ),
      );
      // No stagger anywhere → exactly one Opacity, around the untouched
      // Column (the single-child path never rebuilds the container).
      expect(find.byType(Opacity), findsOneWidget);
      expect(
        find.ancestor(of: find.byType(Column), matching: find.byType(Opacity)),
        findsOneWidget,
      );
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, closeTo(0.5, 1e-9));
    });

    testWidgets('a non-staggered fadeIn in the SAME list keeps wrapping the container', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          frame: 10,
          child:
              Column(
                children: [_square('a'), _square('b'), _square('c')],
              ).animate([
                Animation.slideFadeIn(
                  stagger: const Stagger.each(Time.frames(4)),
                  duration: const Time.frames(20),
                  ease: Ease.linear,
                ),
                Animation.fadeIn(duration: const Time.frames(20), ease: Ease.linear),
              ]),
        ),
      );
      // The container-level fadeIn dims all children equally from outside…
      final containerOpacity = tester.widget<Opacity>(
        find.ancestor(of: find.byType(Flex), matching: find.byType(Opacity)).first,
      );
      expect(containerOpacity.opacity, closeTo(0.5, 1e-9));
      // …while the staggered slideFadeIn still cascades per child inside.
      expect(_opacityOver(tester, 'a'), closeTo(0.5, 1e-9));
      expect(_opacityOver(tester, 'b'), closeTo(0.3, 1e-9));
      expect(_opacityOver(tester, 'c'), closeTo(0.1, 1e-9));
    });

    testWidgets('Defaults(stagger:) via .animate(defaults:) triggers distribution', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          frame: 8,
          child:
              Column(
                children: [_square('a'), _square('b'), _square('c')],
              ).animate(
                [Animation.fadeIn(duration: const Time.frames(20), ease: Ease.linear)],
                defaults: const Defaults(stagger: Stagger.each(Time.frames(4))),
              ),
        ),
      );
      // The inherited stagger distributes: three per-child opacities, none on
      // the container.
      expect(find.byType(Opacity), findsNWidgets(3));
      expect(_opacityOver(tester, 'a'), closeTo(0.4, 1e-9));
      expect(_opacityOver(tester, 'b'), closeTo(0.2, 1e-9));
      expect(_opacityOver(tester, 'c'), closeTo(0.0, 1e-9));
    });
  });

  group('stagger distribution — single-child and exit behavior', () {
    testWidgets('a single-child target ignores stagger', (tester) async {
      await tester.pumpWidget(
        _harness(
          frame: 10,
          child: _square('only').animate([
            Animation.fadeIn(
              stagger: const Stagger.each(Time.frames(4)),
              duration: const Time.frames(20),
              ease: Ease.linear,
            ),
          ]),
        ),
      );
      expect(find.byType(Opacity), findsOneWidget);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, closeTo(0.5, 1e-9));
    });

    testWidgets('a one-child container also ignores stagger', (tester) async {
      await tester.pumpWidget(
        _harness(
          frame: 10,
          child: Column(children: [_square('only')]).animate([
            Animation.fadeIn(
              stagger: const Stagger.each(Time.frames(4)),
              duration: const Time.frames(20),
              ease: Ease.linear,
            ),
          ]),
        ),
      );
      expect(find.byType(Opacity), findsOneWidget);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, closeTo(0.5, 1e-9));
    });

    testWidgets('an exit-phase stagger shifts spans forward: the leading child finishes first', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          frame: 59,
          child:
              Column(
                children: [_square('a'), _square('b')],
              ).animate([
                Animation.fadeOut(
                  stagger: const Stagger.each(Time.frames(6)),
                  duration: const Time.frames(20),
                  ease: Ease.linear,
                ),
              ]),
        ),
      );
      // The base exit span is 40..60 (end-anchored); child 1 shifts to
      // 46..66. At frame 59 child 0 is almost gone, child 1 clearly behind.
      expect(_opacityOver(tester, 'a'), closeTo(0.05, 1e-9));
      expect(_opacityOver(tester, 'b'), closeTo(0.35, 1e-9));
    });
  });

  group('stagger distribution — the D13 base-span contract', () {
    testWidgets('child 0 keeps the unshifted base span exactly', (tester) async {
      Future<double> staggeredChildZeroAt(int frame) async {
        await tester.pumpWidget(
          _harness(
            frame: frame,
            child:
                Column(
                  children: [_square('a'), _square('b'), _square('c')],
                ).animate([
                  Animation.fadeIn(
                    stagger: const Stagger.each(Time.frames(6)),
                    duration: const Time.frames(20),
                    ease: Ease.linear,
                  ),
                ]),
          ),
        );
        return _opacityOver(tester, 'a');
      }

      // The base span is 0..20; child 0's offset is zero, so its progress is
      // exactly the unstaggered animation's at every frame.
      expect(await staggeredChildZeroAt(0), 0.0);
      expect(await staggeredChildZeroAt(5), closeTo(0.25, 1e-9));
      expect(await staggeredChildZeroAt(10), closeTo(0.5, 1e-9));
      expect(await staggeredChildZeroAt(20), 1.0);
    });
  });

  group('stagger distribution — ParentDataWidgets end-to-end', () {
    testWidgets('Expanded children stagger without breaking the flex layout', (tester) async {
      await tester.pumpWidget(
        _harness(
          frame: 6,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child:
                Row(
                  children: [
                    Expanded(child: _square('a')),
                    Expanded(child: _square('b')),
                  ],
                ).animate([
                  Animation.fadeIn(
                    stagger: const Stagger.each(Time.frames(6)),
                    duration: const Time.frames(20),
                    ease: Ease.linear,
                  ),
                ]),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(Expanded), findsNWidgets(2));
      expect(
        tester.getSize(find.byKey(const ValueKey('a'))),
        tester.getSize(find.byKey(const ValueKey('b'))),
      );
      expect(_opacityOver(tester, 'a'), closeTo(0.3, 1e-9));
      expect(_opacityOver(tester, 'b'), closeTo(0.0, 1e-9));
    });
  });
}
