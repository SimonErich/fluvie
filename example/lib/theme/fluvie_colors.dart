import 'package:flutter/painting.dart';

/// The Fluvie brand palette, ported from the landing page
/// (`web/site/src/layouts/Base.astro`). Frame surfaces are dark, content panels
/// are light, and code is always dark.
abstract final class FluvieColors {
  /// Primary blue accent: buttons, links, selection.
  static const acc = Color(0xFF1668E3);

  /// Bright cyan accent: highlights, glows, secondary.
  static const acc2 = Color(0xFF36E1FF);

  /// The darkest surface: app background and code/film cards.
  static const dark = Color(0xFF06070F);

  /// The dark panel surface: nav and card headers.
  static const dpanel = Color(0xFF0A0E1C);

  /// Pure-white content-panel surface.
  static const surface = Color(0xFFFFFFFF);

  /// Primary text on light surfaces.
  static const ink = Color(0xFF0B1020);

  /// Secondary text on light surfaces.
  static const soft = Color(0xFF51607F);

  /// Tertiary/muted text on light surfaces.
  static const muted = Color(0xFF5E6B86);

  /// Hairline border on light surfaces.
  static const line = Color(0xFFECEFF7);

  /// Primary text on dark surfaces.
  static const dtext = Color(0xFFAEBBD8);

  /// Muted text on dark surfaces: filenames, captions.
  static const dmut = Color(0xFF6A7796);

  /// Hairline border on dark surfaces (white at 10%).
  static const dline = Color(0x1AFFFFFF);

  /// Pill/badge text on dark glass.
  static const pillText = Color(0xFFBFE0FF);

  /// Base code text on the dark code surface.
  static const codeText = Color(0xFFCFE6FF);

  /// Code keywords (import, hide, return).
  static const codeKeyword = Color(0xFFC792EA);

  /// Code string literals.
  static const codeString = Color(0xFF7CF3C2);

  /// Code types and classes.
  static const codeType = Color(0xFF36E1FF);

  /// Code function and method names.
  static const codeFunction = Color(0xFF82AAFF);

  /// Code numeric literals.
  static const codeNumber = Color(0xFFF78C6C);

  /// Code comments.
  static const codeComment = Color(0xFF6A7796);

  /// The macOS window red dot.
  static const dotRed = Color(0xFFFF5E7A);

  /// The macOS window yellow dot.
  static const dotYellow = Color(0xFFFFC24B);

  /// The macOS window green dot (also the "ready" status dot).
  static const dotGreen = Color(0xFF7CF3C2);
}
