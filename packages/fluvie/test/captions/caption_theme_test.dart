// WI-16 (D-CaptionTokens, §17/§21): the CaptionTheme token value — the default
// caption style the layer falls back to when a track declares none. Value-equal
// const so two builds of the same theme produce identical captions.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/captions/caption_style.dart';
import 'package:fluvie/src/theme/caption_theme.dart';

void main() {
  group('CaptionTheme.standard', () {
    test('is const-constructible (a compile-time value)', () {
      expect(identical(const CaptionTheme.standard(), const CaptionTheme.standard()), isTrue);
    });

    test('carries a non-null default style', () {
      const theme = CaptionTheme.standard();
      expect(theme.defaultStyle, isA<CaptionStyle>());
    });
  });

  group('CaptionTheme equality', () {
    test('is value-equal with a matching hashCode', () {
      expect(const CaptionTheme.standard(), const CaptionTheme.standard());
      expect(const CaptionTheme.standard().hashCode, const CaptionTheme.standard().hashCode);
    });

    test('differs by default style', () {
      expect(
        const CaptionTheme(defaultStyle: CaptionStyle.subtitle()),
        isNot(const CaptionTheme(defaultStyle: CaptionStyle.tikTok())),
      );
    });
  });
}
