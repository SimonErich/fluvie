// The Phase 11 doc snippets compile and build (WI-40): the theming, templates,
// and multi-aspect pages pull these via code-excerpt markers, so a failing
// build here means a doc would ship dead code.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/snippets/phase_11_snippets.dart';

void main() {
  testWidgets('the brand and type accessors read context.fluvie', (tester) async {
    late List<Color> colors;
    late List<TextStyle> roles;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            colors = brandColors(context);
            roles = typeRoles(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(colors, hasLength(3));
    expect(roles, hasLength(5));
  });

  test('the theme, palette, and type snippets build their tokens', () {
    expect(brandedSubtree(const SizedBox()), isA<Widget>());
    expect(brandPalette(), isA<Palette>());
    expect(typeLadder(), isA<TypeScale>());
    expect(themedText(), isA<Widget>());
  });

  test('the aspect and props menus list the right values', () {
    expect(aspectFamilies(), hasLength(4));
    expect(titleProps().title, '2025');
    expect(statProps().value, 48230);
  });
}
