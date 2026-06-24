import 'package:flutter/painting.dart';

/// The Kitten Mitten brand palette: warm cream surfaces, soft ink text, and a
/// playful pink and tabby accent pair. Shared by every Fluvie example app so the
/// set looks like one cohesive product.
abstract final class KittenColors {
  /// Warm cream: the default app background.
  static const Color cream = Color(0xFFFFF6EC);

  /// Soft charcoal: primary text and outlines.
  static const Color ink = Color(0xFF2B2330);

  /// Mitten pink: the primary brand accent.
  static const Color mitten = Color(0xFFFF8FB1);

  /// Deeper rose: pressed and active accent.
  static const Color mittenDeep = Color(0xFFE5638C);

  /// Tabby orange: the secondary accent.
  static const Color tabby = Color(0xFFF6A04D);

  /// Sky blue: tertiary accent and links.
  static const Color sky = Color(0xFF6CC4E0);

  /// Whisker grey: muted text and icons.
  static const Color whisker = Color(0xFF8A7F92);

  /// Hairline border on cream surfaces.
  static const Color line = Color(0xFFEAD9C7);

  /// White card surface.
  static const Color surface = Color(0xFFFFFFFF);

  /// Success and ready status.
  static const Color ok = Color(0xFF5BB98B);

  /// Warning status.
  static const Color warn = Color(0xFFE0A23B);

  /// Error status.
  static const Color err = Color(0xFFE0635A);
}
