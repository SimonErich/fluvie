import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/transition/cross_fade_strategy.dart';
import 'package:fluvie/src/composition/transition/slide_strategy.dart';
import 'package:fluvie/src/composition/transition/transition_strategy.dart';
import 'package:fluvie/src/composition/transition/wipe_strategy.dart';
import 'package:fluvie/src/composition/transition/zoom_strategy.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/rendering/primitives/fade_box.dart';

const _outgoing = ColoredBox(color: Color(0xFFFF0000));
const _incoming = ColoredBox(color: Color(0xFF0000FF));

/// Mounts a composed pair the way the compositor does: one expanding Stack.
Widget _stack(List<Widget> pair) => SizedBox(
  width: 100,
  height: 100,
  child: Stack(alignment: Alignment.topLeft, fit: StackFit.expand, children: pair),
);

void main() {
  group('strategyFor (D8)', () {
    test('covers every non-cut kind with its own strategy', () {
      expect(strategyFor(TransitionKind.crossFade), isA<CrossFadeStrategy>());
      expect(strategyFor(TransitionKind.wipe), isA<WipeStrategy>());
      expect(strategyFor(TransitionKind.zoom), isA<ZoomStrategy>());
      expect(strategyFor(TransitionKind.slide), isA<SlideStrategy>());
    });

    test('a cut has no strategy: it never opens a blend window', () {
      expect(() => strategyFor(TransitionKind.cut), throwsArgumentError);
    });
  });

  group('CrossFadeStrategy (D9)', () {
    testWidgets('outgoing unwrapped below, incoming above in exactly one FadeBox(te)', (
      tester,
    ) async {
      final pair = const CrossFadeStrategy().compose(
        outgoing: _outgoing,
        incoming: _incoming,
        easedProgress: 0.3,
        spec: Transition.crossFade(10.frames),
      );

      expect(pair, hasLength(2));
      expect(pair.first, same(_outgoing));
      final fade = pair.last;
      expect(fade, isA<FadeBox>());
      expect((fade as FadeBox).opacity, 0.3);
      expect(fade.child, same(_incoming));

      await tester.pumpWidget(_stack(pair));
      expect(find.byType(FadeBox), findsOneWidget);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.3);
    });
  });

  group('WipeStrategy (D9)', () {
    Rect clipAt(Edge direction, double te) {
      final pair = const WipeStrategy().compose(
        outgoing: _outgoing,
        incoming: _incoming,
        easedProgress: te,
        spec: Transition.wipe(10.frames, direction: direction),
      );
      expect(pair.first, same(_outgoing));
      final clip = pair.last as ClipRect;
      expect(clip.child, same(_incoming));
      return clip.clipper!.getClip(const Size(100, 100));
    }

    test('the reveal rect grows in the direction of travel (te = 0.5, all four edges)', () {
      expect(clipAt(Edge.right, 0.5), const Rect.fromLTWH(0, 0, 50, 100));
      expect(clipAt(Edge.left, 0.5), const Rect.fromLTWH(50, 0, 50, 100));
      expect(clipAt(Edge.bottom, 0.5), const Rect.fromLTWH(0, 0, 100, 50));
      expect(clipAt(Edge.top, 0.5), const Rect.fromLTWH(0, 50, 100, 50));
    });

    test('the reveal rect is empty at te 0 and the full canvas at te 1', () {
      expect(clipAt(Edge.right, 0).isEmpty, isTrue);
      expect(clipAt(Edge.right, 1), const Rect.fromLTWH(0, 0, 100, 100));
    });

    testWidgets('mounts the incoming above the outgoing inside the clip', (tester) async {
      final pair = const WipeStrategy().compose(
        outgoing: _outgoing,
        incoming: _incoming,
        easedProgress: 0.5,
        spec: Transition.wipe(10.frames),
      );
      await tester.pumpWidget(_stack(pair));
      expect(find.byType(ClipRect), findsOneWidget);
    });
  });

  group('ZoomStrategy (D9)', () {
    testWidgets('incoming plain below; outgoing on top, scaled 1 → 2.0 into the anchor, fading', (
      tester,
    ) async {
      final pair = const ZoomStrategy().compose(
        outgoing: _outgoing,
        incoming: _incoming,
        easedProgress: 0.5,
        spec: Transition.zoom(10.frames, into: Alignment.bottomRight),
      );

      expect(pair.first, same(_incoming));
      final fade = pair.last as FadeBox;
      expect(fade.opacity, 0.5);
      final transform = fade.child as Transform;
      expect(transform.alignment, Alignment.bottomRight);
      expect(transform.transform.storage[0], 1.5); // lerp(1, 2.0, 0.5)
      expect(transform.transform.storage[5], 1.5);
      expect(transform.child, same(_outgoing));

      await tester.pumpWidget(_stack(pair));
      expect(find.byType(Transform), findsOneWidget);
    });
  });

  group('SlideStrategy (D9)', () {
    testWidgets('a push from the right: documented fractional translations at te = 0.25', (
      tester,
    ) async {
      final pair = const SlideStrategy().compose(
        outgoing: _outgoing,
        incoming: _incoming,
        easedProgress: 0.25,
        spec: Transition.slide(10.frames),
      );

      final out = pair.first as FractionalTranslation;
      expect(out.translation, const Offset(-0.25, 0));
      expect(out.child, same(_outgoing));
      final inc = pair.last as FractionalTranslation;
      expect(inc.translation, const Offset(0.75, 0));
      expect(inc.child, same(_incoming));

      await tester.pumpWidget(_stack(pair));
      expect(find.byType(FractionalTranslation), findsNWidgets(2));
    });

    test('a push from the top translates vertically with the Edge.dy convention', () {
      final pair = const SlideStrategy().compose(
        outgoing: _outgoing,
        incoming: _incoming,
        easedProgress: 0.25,
        spec: Transition.slide(10.frames, from: Edge.top),
      );

      expect((pair.first as FractionalTranslation).translation, const Offset(0, 0.25));
      expect((pair.last as FractionalTranslation).translation, const Offset(0, -0.75));
    });
  });
}
