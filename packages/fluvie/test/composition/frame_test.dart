// WI-28 (D15): the Frame micro-defaults, structure-pinned here and pixel-
// pinned by the layout goldens. All values are pre-1.0 defaults, trivially
// changeable; the polaroid caption and the card's radius/elevation params
// join with the Phase 8 media elements (API_SPEC §15).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/frame.dart';

const _child = SizedBox(key: Key('subject'), width: 60, height: 40);
const _shadow = BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 8));

void main() {
  group('Frame (D15, §14)', () {
    testWidgets('none is a pure passthrough', (tester) async {
      await tester.pumpWidget(const Center(child: Frame.none(child: _child)));
      expect(find.byKey(const Key('subject')), findsOneWidget);
      expect(find.byType(ClipRRect), findsNothing);
      expect(find.byType(DecoratedBox), findsNothing);
      expect(find.byType(Padding), findsNothing);
    });

    testWidgets('rounded clips at its radius (default 24)', (tester) async {
      await tester.pumpWidget(const Center(child: Frame.rounded(child: _child)));
      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clip.borderRadius, BorderRadius.circular(24));
    });

    testWidgets('rounded forwards an explicit radius', (tester) async {
      await tester.pumpWidget(const Center(child: Frame.rounded(radius: 8, child: _child)));
      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clip.borderRadius, BorderRadius.circular(8));
    });

    testWidgets('card: white surface, radius 16, padding 12, one deterministic shadow', (
      tester,
    ) async {
      await tester.pumpWidget(const Center(child: Frame.card(child: _child)));
      final decoration =
          tester.widget<DecoratedBox>(find.byType(DecoratedBox)).decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFFFFFFF));
      expect(decoration.borderRadius, BorderRadius.circular(16));
      expect(decoration.boxShadow, const [_shadow]);
      expect(tester.widget<Padding>(find.byType(Padding)).padding, const EdgeInsets.all(12));
      expect(
        find.descendant(of: find.byType(Padding), matching: find.byKey(const Key('subject'))),
        findsOneWidget,
      );
    });

    testWidgets('polaroid: square white border 12/12/12/48 with the same shadow', (tester) async {
      await tester.pumpWidget(const Center(child: Frame.polaroid(child: _child)));
      final decoration =
          tester.widget<DecoratedBox>(find.byType(DecoratedBox)).decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFFFFFFF));
      expect(decoration.borderRadius, isNull);
      expect(decoration.boxShadow, const [_shadow]);
      expect(
        tester.widget<Padding>(find.byType(Padding)).padding,
        const EdgeInsets.fromLTRB(12, 12, 12, 48),
      );
    });

    testWidgets('card and polaroid wrap the child tightly (no expansion)', (tester) async {
      await tester.pumpWidget(const Center(child: Frame.card(child: _child)));
      expect(tester.getSize(find.byType(Frame)), const Size(60 + 24, 40 + 24));
      await tester.pumpWidget(const Center(child: Frame.polaroid(child: _child)));
      expect(tester.getSize(find.byType(Frame)), const Size(60 + 24, 40 + 60));
    });
  });

  group('Frame Phase 8 params (WI-10, §15)', () {
    testWidgets('polaroid renders the caption text in the bottom border', (tester) async {
      await tester.pumpWidget(
        const Center(
          child: Frame.polaroid(caption: 'Summer', child: _child),
        ),
      );
      expect(find.text('Summer'), findsOneWidget);
    });

    testWidgets('polaroid without a caption renders no caption text', (tester) async {
      await tester.pumpWidget(const Center(child: Frame.polaroid(child: _child)));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('card forwards radius and elevation to the surface', (tester) async {
      await tester.pumpWidget(
        const Center(child: Frame.card(radius: 24, elevation: 16, child: _child)),
      );
      final decoration =
          tester.widget<DecoratedBox>(find.byType(DecoratedBox)).decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(24));
      expect(decoration.boxShadow!.single.blurRadius, 16);
    });

    test('card defaults are unchanged (radius 16)', () {
      const frame = Frame.card(child: _child);
      expect(frame.radius, 16);
    });

    testWidgets('withChild re-issues the same style with a new child', (tester) async {
      const newChild = SizedBox(key: Key('new'), width: 10, height: 10);
      final framed = const Frame.card(child: _child).withChild(newChild);
      await tester.pumpWidget(Center(child: framed));
      expect(find.byKey(const Key('new')), findsOneWidget);
      expect(find.byKey(const Key('subject')), findsNothing);
      final decoration =
          tester.widget<DecoratedBox>(find.byType(DecoratedBox)).decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(16));
    });

    testWidgets('withChild preserves a polaroid caption', (tester) async {
      const newChild = SizedBox(key: Key('new'), width: 10, height: 10);
      final framed = const Frame.polaroid(caption: 'Trip').withChild(newChild);
      await tester.pumpWidget(Center(child: framed));
      expect(find.text('Trip'), findsOneWidget);
      expect(find.byKey(const Key('new')), findsOneWidget);
    });
  });
}
