import 'package:flutter/widgets.dart';

import 'package:kitten_kit/src/theme/kitten_colors.dart';

/// The Kitten Mitten type scale for app chrome (not the rendered video). It uses
/// the platform default font, so no font assets need bundling.
abstract final class KittenType {
  /// Large playful display for hero headings.
  static const TextStyle display = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: KittenColors.ink,
    height: 1.1,
  );

  /// Section and screen titles.
  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: KittenColors.ink,
  );

  /// Body copy.
  static const TextStyle body = TextStyle(
    fontSize: 15,
    color: KittenColors.ink,
    height: 1.35,
  );

  /// Muted captions and helper text.
  static const TextStyle caption = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: KittenColors.whisker,
  );
}
