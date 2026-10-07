import 'package:flutter/widgets.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Image;
import 'tiny_png.dart';

void main() {
  testWidgets('cornerRadius clips the image to a rounded rect', (tester) async {
    await tester.pumpWidget(
      Center(
        child: SizedBox(
          width: 100,
          height: 100,
          child: Image.memory(tinyPng, cornerRadius: 12),
        ),
      ),
    );
    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
    expect(clip.borderRadius, const BorderRadius.all(Radius.circular(12)));
  });

  testWidgets('no cornerRadius mounts no clip', (tester) async {
    await tester.pumpWidget(
      Center(
        child: SizedBox(width: 100, height: 100, child: Image.memory(tinyPng)),
      ),
    );
    expect(find.byType(ClipRRect), findsNothing);
  });

  testWidgets('crop shows exactly the source-fraction region', (tester) async {
    // Crop the top-right quarter: the full image must render at twice the
    // box size, shifted so that quarter fills the box.
    await tester.pumpWidget(
      Center(
        child: SizedBox(
          width: 100,
          height: 80,
          child: Image.memory(
            tinyPng,
            crop: const Rect.fromLTWH(0.5, 0, 0.5, 0.5),
          ),
        ),
      ),
    );
    final overflow = tester.widget<OverflowBox>(find.byType(OverflowBox));
    expect(overflow.maxWidth, 200);
    expect(overflow.maxHeight, 160);
    final translate = tester.widget<Transform>(find.byType(Transform));
    expect(translate.transform.getTranslation().x, -100);
    expect(translate.transform.getTranslation().y, 0);
    expect(find.byType(ClipRect), findsOneWidget);
  });

  testWidgets('crop and cornerRadius compose', (tester) async {
    await tester.pumpWidget(
      Center(
        child: SizedBox(
          width: 100,
          height: 100,
          child: Image.memory(
            tinyPng,
            crop: const Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
            cornerRadius: 8,
          ),
        ),
      ),
    );
    expect(find.byType(ClipRRect), findsOneWidget);
    expect(find.byType(ClipRect), findsOneWidget);
    final size = tester.getSize(find.byType(ClipRRect));
    expect(size, const Size(100, 100));
  });
}
