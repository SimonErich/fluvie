import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/effect_kind.dart';

/// Gaussian blur of the element itself. Uses [ImageFiltered], never a
/// backdrop read, so an off-screen capture sees exactly the preview.
final class BlurEffect implements PixelAnimationEffect {
  /// Creates a blur with [sigma] logical pixels in both axes.
  const BlurEffect(this.sigma);

  /// Blur radius; zero returns the unwrapped child exactly.
  final double sigma;

  @override
  Widget build(Widget child, double progress) => sigma <= 0
      ? child
      : ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: child,
        );
}
