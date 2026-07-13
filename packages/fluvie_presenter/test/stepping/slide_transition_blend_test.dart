import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Edge, Time, Transition;
import 'package:fluvie_presenter/src/stepping/slide_transition_blend.dart';

Widget _blend(WidgetTester tester, Transition transition, double progress) => SlideTransitionBlend(
  transition: transition,
  progress: AlwaysStoppedAnimation<double>(progress),
  outgoing: const SizedBox(width: 100, height: 50, key: ValueKey('out')),
  incoming: const SizedBox(width: 100, height: 50, key: ValueKey('in')),
);

void main() {
  Future<void> pump(WidgetTester tester, Transition transition, {double progress = 0.5}) =>
      tester.pumpWidget(
        Center(
          child: SizedBox(width: 100, height: 50, child: _blend(tester, transition, progress)),
        ),
      );

  testWidgets('a cut renders only the incoming slide', (tester) async {
    await pump(tester, const Transition.cut());
    expect(find.byKey(const ValueKey('in')), findsOneWidget);
    expect(find.byKey(const ValueKey('out')), findsNothing);
  });

  testWidgets('a crossFade keeps both slides on stage, incoming fading in', (tester) async {
    await pump(tester, const Transition.crossFade(Time.seconds(0.5)));
    expect(find.byKey(const ValueKey('in')), findsOneWidget);
    expect(find.byKey(const ValueKey('out')), findsOneWidget);
    final fade = tester.widget<FadeTransition>(
      find.ancestor(of: find.byKey(const ValueKey('in')), matching: find.byType(FadeTransition)),
    );
    expect(fade.opacity.value, 0.5);
  });

  testWidgets('a slide pushes the incoming slide in from its edge', (tester) async {
    for (final edge in Edge.values) {
      await pump(tester, Transition.slide(const Time.seconds(0.5), from: edge), progress: 0);
      final slide = tester.widget<SlideTransition>(
        find.ancestor(of: find.byKey(const ValueKey('in')), matching: find.byType(SlideTransition)),
      );
      final offset = slide.position.value;
      expect(offset.distance, 1, reason: 'at progress 0 the slide sits one box off $edge');
    }
  });

  testWidgets('a wipe clips the incoming slide toward its direction', (tester) async {
    for (final edge in Edge.values) {
      await pump(tester, Transition.wipe(const Time.seconds(0.5), direction: edge));
      expect(find.byKey(const ValueKey('in')), findsOneWidget);
      expect(find.byKey(const ValueKey('out')), findsOneWidget);
      final clip = tester.widget<ClipRect>(
        find.ancestor(of: find.byKey(const ValueKey('in')), matching: find.byType(ClipRect)),
      );
      final rect = clip.clipper!.getClip(const Size(100, 50));
      expect(rect.width * rect.height, 100 * 50 / 2, reason: 'half revealed along $edge');
      expect(clip.clipper!.shouldReclip(clip.clipper!), isFalse);
    }
  });

  testWidgets('a zoom scales and fades the outgoing slide away on top', (tester) async {
    await pump(tester, const Transition.zoom(Time.seconds(0.5)));
    expect(find.byKey(const ValueKey('in')), findsOneWidget);
    final scale = tester.widget<ScaleTransition>(
      find.ancestor(of: find.byKey(const ValueKey('out')), matching: find.byType(ScaleTransition)),
    );
    expect(scale.scale.value, closeTo(1.075, 0.001));
    final fade = tester.widget<FadeTransition>(
      find.ancestor(of: find.byKey(const ValueKey('out')), matching: find.byType(FadeTransition)),
    );
    expect(fade.opacity.value, 0.5);
  });
}
