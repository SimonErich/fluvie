import 'package:flutter/painting.dart';

import 'package:fluvie_example/theme/fluvie_colors.dart';

/// The Fluvie brand gradients, ported from the landing page. The primary
/// cyan-to-blue gradient drives CTAs and accents; the radial gradients paint the
/// dark frame backdrop and the film stage.
abstract final class FluvieGradients {
  /// The signature cyan -> blue -> deep-blue CTA and accent gradient
  /// (CSS `120deg`, approximated top-left to bottom-right).
  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF36E1FF), Color(0xFF1668E3), Color(0xFF0B3FB0)],
    stops: [0, 0.6, 1],
  );

  /// The dark frame backdrop: a deep-blue radial fading to near-black, anchored
  /// above the top edge.
  static const heroBackdrop = RadialGradient(
    center: Alignment(0, -1.24),
    radius: 1.4,
    colors: [Color(0xFF123073), Color(0xFF0A1742), FluvieColors.dark],
    stops: [0, 0.4, 1],
  );

  /// The film/video stage: a blue radial fading to near-black.
  static const filmStage = RadialGradient(
    center: Alignment(0, -0.3),
    radius: 1.2,
    colors: [Color(0xFF16357F), FluvieColors.dark],
  );

  /// The soft cyan glow behind the hero and the film stage.
  static const glow = RadialGradient(
    colors: [Color(0x4236E1FF), Color(0x261668E3), Color(0x0036E1FF)],
    stops: [0, 0.38, 0.66],
  );
}
