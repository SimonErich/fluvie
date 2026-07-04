import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter/widgets.dart' as flutter show BackdropFilter;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/annotations/callout.dart';
import 'package:fluvie/src/elements/annotations/lower_third.dart';
import 'package:fluvie/src/elements/annotations/render/spotlight_painter.dart';
import 'package:fluvie/src/elements/annotations/spotlight.dart';
import 'package:fluvie/src/elements/annotations/title_card.dart';

import 'annotation_harness.dart';

SpotlightPainter _spotlightPainter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(Spotlight), matching: find.byType(CustomPaint)).first,
  );
  return paint.painter! as SpotlightPainter;
}

void main() {
  group('Spotlight', () {
    testWidgets('dims everything but the region via an even-odd fill', (tester) async {
      await pumpAnnotation(
        tester,
        const Spotlight.on(
          region: Rect.fromLTWH(20, 20, 40, 40),
          child: ColoredBox(color: Color(0xFF223344)),
        ),
      );
      final painter = _spotlightPainter(tester);
      expect(painter.region, const Rect.fromLTWH(20, 20, 40, 40));
      // The dim path uses the even-odd rule so the region punches a hole.
      expect(painter.usesEvenOdd, isTrue);
    });

    testWidgets('the reveal grows the hole from 0 to the full region', (tester) async {
      const spotlight = Spotlight.on(
        region: Rect.fromLTWH(20, 20, 40, 40),
        reveal: Time.frames(10),
        child: ColoredBox(color: Color(0xFF223344)),
      );
      await pumpAnnotation(tester, spotlight);
      expect(_spotlightPainter(tester).reveal, 0);
      await pumpAnnotation(tester, spotlight, frame: 5);
      expect(_spotlightPainter(tester).reveal, closeTo(0.5, 1e-9));
      await pumpAnnotation(tester, spotlight, frame: 10);
      expect(_spotlightPainter(tester).reveal, 1);
    });

    testWidgets('renders its child behind the dim', (tester) async {
      await pumpAnnotation(
        tester,
        const Spotlight.on(
          region: Rect.fromLTWH(0, 0, 50, 50),
          child: Text('under', textDirection: TextDirection.ltr),
        ),
      );
      expect(find.text('under'), findsOneWidget);
    });

    testWidgets('shared wraps the spotlight in a SharedElement', (tester) async {
      final anchor = Anchor('spot');
      await pumpAnnotation(
        tester,
        Spotlight.on(
          region: const Rect.fromLTWH(0, 0, 50, 50),
          shared: anchor,
          child: const SizedBox(),
        ),
      );
      expect(find.byType(SharedElement), findsOneWidget);
    });

    testWidgets('dims with no BackdropFilter (capture-safe)', (tester) async {
      await pumpAnnotation(
        tester,
        const Spotlight.on(
          region: Rect.fromLTWH(0, 0, 50, 50),
          child: ColoredBox(color: Color(0xFF223344)),
        ),
      );
      expect(find.byType(flutter.BackdropFilter), findsNothing);
    });
  });

  group('annotations compose with .animate()', () {
    testWidgets('Spotlight.animate wraps it in a MotionTarget', (tester) async {
      await pumpAnnotation(
        tester,
        const Spotlight.on(
          region: Rect.fromLTWH(0, 0, 50, 50),
          child: SizedBox(),
        ).animate([Animation.fadeIn()]),
      );
      expect(find.byType(MotionTarget), findsOneWidget);
      expect(find.byType(Spotlight), findsOneWidget);
    });

    testWidgets('TitleCard.animate wraps it in a MotionTarget', (tester) async {
      await pumpAnnotation(
        tester,
        const TitleCard(title: 'Hi').animate([Animation.fadeIn()]),
      );
      expect(find.byType(MotionTarget), findsOneWidget);
    });
  });

  group('Callout', () {
    testWidgets('shows its label and arrow toward the target', (tester) async {
      await pumpAnnotation(
        tester,
        const Callout(
          label: 'Look here',
          target: Offset(80, 80),
          child: SizedBox(),
        ),
      );
      expect(find.text('Look here'), findsOneWidget);
    });

    testWidgets('renders its annotated child', (tester) async {
      await pumpAnnotation(
        tester,
        const Callout(
          label: 'Note',
          target: Offset(40, 40),
          child: Text('content', textDirection: TextDirection.ltr),
        ),
      );
      expect(find.text('content'), findsOneWidget);
    });
  });

  group('LowerThird', () {
    testWidgets('shows the name and optional title', (tester) async {
      await pumpAnnotation(
        tester,
        const LowerThird(name: 'Ada Lovelace', title: 'Mathematician'),
      );
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Mathematician'), findsOneWidget);
    });

    testWidgets('slides in from the edge over its reveal (offset shrinks)', (tester) async {
      const lowerThird = LowerThird(name: 'Ada', slideIn: Time.frames(10));
      await pumpAnnotation(tester, lowerThird);
      final atStart = _slideDx(tester);
      await pumpAnnotation(tester, lowerThird, frame: 10);
      final atEnd = _slideDx(tester);
      expect(atStart.abs(), greaterThan(atEnd.abs()));
      expect(atEnd, 0);
    });
  });

  group('TitleCard', () {
    testWidgets('shows a centered title and optional subtitle', (tester) async {
      await pumpAnnotation(
        tester,
        const TitleCard(title: 'Chapter One', subtitle: 'The beginning'),
      );
      expect(find.text('Chapter One'), findsOneWidget);
      expect(find.text('The beginning'), findsOneWidget);
    });

    testWidgets('reveals over its window (opacity grows)', (tester) async {
      const card = TitleCard(title: 'Hi', reveal: Time.frames(10));
      await pumpAnnotation(tester, card);
      final atStart = _titleOpacity(tester);
      await pumpAnnotation(tester, card, frame: 10);
      final atEnd = _titleOpacity(tester);
      expect(atEnd, greaterThan(atStart));
      expect(atEnd, 1);
    });

    testWidgets('shared wraps the card in a SharedElement', (tester) async {
      final anchor = Anchor('card');
      await pumpAnnotation(
        tester,
        TitleCard(title: 'Hi', shared: anchor),
      );
      expect(find.byType(SharedElement), findsOneWidget);
    });
  });
}

/// The horizontal translation of the lower-third bar at the current frame.
double _slideDx(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.descendant(of: find.byType(LowerThird), matching: find.byType(Transform)).first,
  );
  return transform.transform.getTranslation().x;
}

/// The opacity of the title card content at the current frame.
double _titleOpacity(WidgetTester tester) {
  final opacity = tester.widget<Opacity>(
    find.descendant(of: find.byType(TitleCard), matching: find.byType(Opacity)).first,
  );
  return opacity.opacity;
}
