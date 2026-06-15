// WI-26 (D16): FadeBox is the named render-safe fade primitive — paint-
// equivalent to the raw Opacity it replaces by construction: Opacity for
// every value except exactly 1.0, where it skips the wrap entirely.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/primitives/fade_box.dart';

void main() {
  const child = SizedBox(key: Key('subject'), width: 10, height: 10);

  Future<void> pump(WidgetTester tester, double opacity) => tester.pumpWidget(
    Center(
      child: FadeBox(opacity: opacity, child: child),
    ),
  );

  group('FadeBox (D16)', () {
    testWidgets('0.5 mounts exactly one Opacity(0.5)', (tester) async {
      await pump(tester, 0.5);
      expect(find.byType(Opacity), findsOneWidget);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.5);
      expect(find.byKey(const Key('subject')), findsOneWidget);
    });

    testWidgets('exactly 1.0 skips the wrap: no Opacity in the tree', (tester) async {
      await pump(tester, 1);
      expect(find.byType(Opacity), findsNothing);
      expect(find.byKey(const Key('subject')), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('subject'))), const Size(10, 10));
    });

    testWidgets('0.0 mounts Opacity(0) with the layout slot held', (tester) async {
      await pump(tester, 0);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.0);
      // RenderOpacity skips painting at 0, but the child still lays out.
      expect(tester.getSize(find.byKey(const Key('subject'))), const Size(10, 10));
    });

    testWidgets('overshot opacity clamps into Opacity bounds (1.08 -> 1.0)', (tester) async {
      await pump(tester, 1.08);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1.0);
    });

    testWidgets('undershot opacity clamps into Opacity bounds (-0.4 -> 0.0)', (tester) async {
      await pump(tester, -0.4);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.0);
    });

    testWidgets('the raw value survives on the widget for probes', (tester) async {
      await pump(tester, 1.08);
      expect(tester.widget<FadeBox>(find.byType(FadeBox)).opacity, 1.08);
    });
  });
}
