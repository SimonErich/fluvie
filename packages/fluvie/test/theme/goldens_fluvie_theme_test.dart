// Epic 14.1 (WI-5, §14.1.3): the themed-render golden. Under a FluvieTheme, a
// widget derives its colors and fonts from context.fluvie.brand / .type — a Box
// filled with context.fluvie.brand.accent above a Text styled with
// context.fluvie.type.title. The same subject with no theme would read the
// neutral fallback; this pins the themed read end to end. The existing element
// goldens are proven byte-identical WITHOUT a theme by their own families (the
// retrofit-neutrality pin); this file adds the one new themed golden.
@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/box.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/theme/build_context_tokens.dart';
import 'package:fluvie/src/theme/fluvie_theme.dart';
import 'package:fluvie/src/theme/palette.dart';
import 'package:fluvie/src/theme/type_scale.dart';

const _brand = Palette(
  bg: Color(0xFF0E0E12),
  accent: Color(0xFF6C5CE7),
  onBg: Color(0xFFFFFFFF),
);

/// A subject that reads its accent fill and title style from the theme.
class _BrandedCard extends StatelessWidget {
  const _BrandedCard();

  @override
  Widget build(BuildContext context) {
    final tokens = context.fluvie;
    return ColoredBox(
      color: tokens.brand.bg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 16,
            child: Box(color: tokens.brand.accent),
          ),
          const SizedBox(height: 12),
          Text(
            'AA',
            textDirection: TextDirection.ltr,
            style: tokens.type.title.copyWith(color: tokens.brand.accent),
          ),
        ],
      ),
    );
  }
}

Future<void> main() async {
  await goldenTest(
    'FluvieTheme: a Box and a Text derive their accent and title from context.fluvie',
    fileName: 'fluvie_theme_branded',
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(
          name: 'branded',
          child: const SizedBox(
            width: 140,
            height: 120,
            child: FluvieTheme(
              palette: _brand,
              motion: Defaults(duration: Time.seconds(0.4), ease: Ease.out),
              child: _BrandedCard(),
            ),
          ),
        ),
        GoldenTestScenario(
          name: 'larger-type',
          child: SizedBox(
            width: 140,
            height: 120,
            child: FluvieTheme(
              palette: _brand,
              type: TypeScale.fromBase(24),
              child: const _BrandedCard(),
            ),
          ),
        ),
      ],
    ),
  );
}
