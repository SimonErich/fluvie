import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/animation_effect.dart';
import 'package:fluvie/src/animation/runtime/animation_pipeline.dart';
import 'package:fluvie/src/animation/runtime/keyframe_scope.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/schedule/element_schedule.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

import '../fakes/fake_pixel_effect.dart';

const _scope = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 60);

/// A merged-cascade stand-in: linear ease so progress probes are exact.
const _defaults = Defaults(duration: Time.frames(20), ease: Ease.linear);

ElementSchedule _schedule(
  List<ResolvedSpan> spans, {
  ResolvedSpan window = const ResolvedSpan(0, 60),
}) => ElementSchedule(window: window, spans: spans, defaults: _defaults);

/// A transform-class custom effect leaving a findable marker in the tree.
final class _MarkerEffect implements AnimationEffect {
  const _MarkerEffect(this.key);

  final Key key;

  @override
  Widget build(Widget child, double progress) => KeyedSubtree(key: key, child: child);
}

void main() {
  const square = SizedBox(width: 20, height: 20, child: ColoredBox(color: Color(0xFF112233)));

  group('buildAnimatedFrame — §27.6 ordering', () {
    const marker = Key('custom transform');

    Future<void> pumpList(WidgetTester tester, List<Animation> animations) => tester.pumpWidget(
      buildAnimatedFrame(
        child: square,
        animations: animations,
        schedule: _schedule(const [ResolvedSpan(0, 20), ResolvedSpan(0, 20)]),
        elementScope: _scope,
        frame: 10,
      ),
    );

    testWidgets('[custom, fakePixel] puts the pixel effect outermost', (tester) async {
      await pumpList(tester, [
        const Animation.custom(_MarkerEffect(marker)),
        const Animation.custom(FakePixelEffect()),
      ]);
      expect(
        find.descendant(of: find.byType(DecoratedBox), matching: find.byKey(marker)),
        findsOneWidget,
      );
    });

    testWidgets('[fakePixel, custom] also puts the pixel effect outermost', (tester) async {
      await pumpList(tester, [
        const Animation.custom(FakePixelEffect()),
        const Animation.custom(_MarkerEffect(marker)),
      ]);
      expect(
        find.descendant(of: find.byType(DecoratedBox), matching: find.byKey(marker)),
        findsOneWidget,
      );
    });
  });

  group('buildAnimatedFrame — keyframe composition (D5)', () {
    testWidgets('two keyframe animations compose into exactly one applier stack', (tester) async {
      await tester.pumpWidget(
        buildAnimatedFrame(
          child: square,
          animations: [
            Animation.from(const Keyframe(opacity: 0), duration: const Time.frames(20)),
            Animation.from(const Keyframe(y: 0.5), duration: const Time.frames(20)),
          ],
          schedule: _schedule(const [ResolvedSpan(0, 20), ResolvedSpan(0, 20)]),
          elementScope: _scope,
          frame: 10,
        ),
      );
      expect(find.byType(Opacity), findsOneWidget);
      expect(find.byType(FractionalTranslation), findsOneWidget);
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      final slide = tester.widget<FractionalTranslation>(find.byType(FractionalTranslation));
      expect(opacity.opacity, closeTo(0.5, 1e-9));
      expect(slide.translation.dy, closeTo(0.25, 1e-9));
    });

    testWidgets('an overlapping field goes to the later animation in the list', (tester) async {
      await tester.pumpWidget(
        buildAnimatedFrame(
          child: square,
          animations: [
            Animation.fromTo(const Keyframe(opacity: 0.3), const Keyframe(opacity: 0.3)),
            Animation.fromTo(const Keyframe(opacity: 0.9), const Keyframe(opacity: 0.9)),
          ],
          schedule: _schedule(const [ResolvedSpan(0, 20), ResolvedSpan(0, 20)]),
          elementScope: _scope,
          frame: 10,
        ),
      );
      expect(find.byType(Opacity), findsOneWidget);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, closeTo(0.9, 1e-9));
    });

    testWidgets('disjoint fields commute across list order', (tester) async {
      final fade = Animation.from(const Keyframe(opacity: 0), duration: const Time.frames(20));
      final slide = Animation.from(const Keyframe(x: 1), duration: const Time.frames(20));
      Future<({double opacity, Offset offset})> probe(List<Animation> animations) async {
        await tester.pumpWidget(
          buildAnimatedFrame(
            child: square,
            animations: animations,
            schedule: _schedule(const [ResolvedSpan(0, 20), ResolvedSpan(0, 20)]),
            elementScope: _scope,
            frame: 5,
          ),
        );
        return (
          opacity: tester.widget<Opacity>(find.byType(Opacity)).opacity,
          offset: tester
              .widget<FractionalTranslation>(find.byType(FractionalTranslation))
              .translation,
        );
      }

      final forward = await probe([fade, slide]);
      final reversed = await probe([slide, fade]);
      expect(forward.opacity, reversed.opacity);
      expect(forward.offset, reversed.offset);
    });

    testWidgets('MultiKeyframeEffect at: times resolve to stop fractions (D17)', (tester) async {
      final keyframes = Animation.keyframes(
        const [Keyframe(x: 0), Keyframe(x: 1), Keyframe(x: 0)],
        at: const [Time.zero, Time.frames(5), Time.frames(20)],
        duration: const Time.frames(20),
        ease: Ease.linear,
      );
      await tester.pumpWidget(
        buildAnimatedFrame(
          child: square,
          animations: [keyframes],
          schedule: _schedule(const [ResolvedSpan(0, 20)]),
          elementScope: _scope,
          frame: 5,
        ),
      );
      // Progress 0.25 lands exactly on the explicit middle stop (5/20), so
      // x is 1 — even spacing would give 0.5 here.
      final slide = tester.widget<FractionalTranslation>(find.byType(FractionalTranslation));
      expect(slide.translation.dx, closeTo(1, 1e-9));
    });
  });

  group('buildAnimatedFrame — window visibility (D7)', () {
    Widget rowWith(Widget animated) => Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          animated,
          const SizedBox(key: Key('sibling'), width: 20, height: 20),
        ],
      ),
    );

    Widget animatedAt(int frame) => buildAnimatedFrame(
      child: square,
      animations: [
        Animation.from(const Keyframe(y: 0.5), duration: const Time.frames(10)),
      ],
      schedule: _schedule(const [ResolvedSpan(10, 20)], window: const ResolvedSpan(10, 40)),
      elementScope: _scope,
      frame: frame,
    );

    testWidgets('a frame before the window forces opacity 0 and keeps the layout slot', (
      tester,
    ) async {
      await tester.pumpWidget(rowWith(animatedAt(20)));
      final inWindow = tester.getTopLeft(find.byKey(const Key('sibling')));
      // In-window with a y-only keyframe: nothing forces opacity, so the
      // applier mounts no Opacity at all.
      expect(find.byType(Opacity), findsNothing);

      await tester.pumpWidget(rowWith(animatedAt(5)));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.0);
      expect(tester.getTopLeft(find.byKey(const Key('sibling'))), inWindow);
    });

    testWidgets('a frame at/after the window end also forces opacity 0', (tester) async {
      await tester.pumpWidget(rowWith(animatedAt(40)));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.0);
    });
  });

  group('buildAnimatedFrame — KeyframeScope publication (D9)', () {
    testWidgets('publishes the composed keyframe, lerped color included', (tester) async {
      Keyframe? published;
      final probe = Builder(
        builder: (context) {
          published = KeyframeScope.maybeOf(context);
          return square;
        },
      );
      await tester.pumpWidget(
        buildAnimatedFrame(
          child: probe,
          animations: [
            Animation.fromTo(
              const Keyframe(color: Color(0xFF000000)),
              const Keyframe(color: Color(0xFFFFFFFF)),
            ),
            Animation.from(const Keyframe(opacity: 0), duration: const Time.frames(20)),
          ],
          schedule: _schedule(const [ResolvedSpan(0, 20), ResolvedSpan(0, 20)]),
          elementScope: _scope,
          frame: 10,
        ),
      );
      expect(published, isNotNull);
      expect(published!.opacity, closeTo(0.5, 1e-9));
      expect(
        published!.color,
        Color.lerp(const Color(0xFF000000), const Color(0xFFFFFFFF), 0.5),
      );
    });
  });

  group('buildAnimatedFrame — span shifts and repeat', () {
    testWidgets('spanShifts move an animation span without touching the window', (tester) async {
      Widget at({required List<int>? shifts}) => buildAnimatedFrame(
        child: square,
        animations: [
          Animation.from(const Keyframe(opacity: 0), duration: const Time.frames(20)),
        ],
        schedule: _schedule(const [ResolvedSpan(0, 20)]),
        elementScope: _scope,
        frame: 10,
        spanShifts: shifts,
      );

      await tester.pumpWidget(at(shifts: null));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, closeTo(0.5, 1e-9));

      await tester.pumpWidget(at(shifts: const [10]));
      // The span became 10..30, so frame 10 is its very start: opacity 0.
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.0);
    });

    testWidgets('a during repeat loops at the effective cycle length (D12)', (tester) async {
      Future<double> opacityAt(int frame) async {
        await tester.pumpWidget(
          buildAnimatedFrame(
            child: square,
            animations: [
              Animation.fromTo(
                const Keyframe(opacity: 0),
                const Keyframe(opacity: 1),
                phase: AnimationPhase.during,
                duration: const Time.frames(10),
                ease: Ease.linear,
                repeat: const Repeat.forever(),
              ),
            ],
            schedule: _schedule(const [ResolvedSpan(0, 60)]),
            elementScope: _scope,
            frame: frame,
          ),
        );
        return tester.widget<Opacity>(find.byType(Opacity)).opacity;
      }

      // Cycle length is the 10-frame effective duration, not the 60-frame span.
      expect(await opacityAt(25), closeTo(0.5, 1e-9));
      expect(await opacityAt(12), closeTo(0.2, 1e-9));
    });
  });
}
