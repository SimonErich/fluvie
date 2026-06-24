import 'package:flutter/painting.dart';

/// Brand corner radii, ported from the landing page.
abstract final class FluvieRadii {
  /// Buttons and inputs.
  static const button = 12.0;

  /// Cards and code/film windows.
  static const card = 16.0;

  /// Pills and badges.
  static const pill = 30.0;

  /// Small chips and language tags.
  static const chip = 8.0;
}

/// Brand drop shadows, ported from the landing page.
abstract final class FluvieElevations {
  /// Code/film window shadow (`0 30 60 -28 rgba(0,0,0,.6)`).
  static const codeWindow = [
    BoxShadow(color: Color(0x99000000), blurRadius: 60, spreadRadius: -28, offset: Offset(0, 30)),
  ];

  /// Light content-card shadow (`0 20 44 -32 rgba(11,16,32,.2)`).
  static const lightCard = [
    BoxShadow(color: Color(0x330B1020), blurRadius: 44, spreadRadius: -32, offset: Offset(0, 20)),
  ];

  /// CTA gradient-button glow (`0 12 28 rgba(22,104,227,.4)`).
  static const ctaGlow = [
    BoxShadow(color: Color(0x661668E3), blurRadius: 28, offset: Offset(0, 12)),
  ];

  /// CTA gradient-button glow on hover (`0 16 34 rgba(22,104,227,.5)`).
  static const ctaGlowStrong = [
    BoxShadow(color: Color(0x801668E3), blurRadius: 34, offset: Offset(0, 16)),
  ];
}
