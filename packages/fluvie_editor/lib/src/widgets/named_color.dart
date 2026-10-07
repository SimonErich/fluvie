import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show immutable;

// obers_ui upstream candidate: a color with a display name — what a themed
// swatch row shows and binds against.

/// A named swatch: what a theme palette entry looks like to a color picker.
@immutable
final class NamedColor {
  /// The swatch [color] shown under [name].
  const NamedColor({required this.name, required this.color});

  /// The swatch's display (and binding) name.
  final String name;

  /// The swatch's color.
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is NamedColor && other.name == name && other.color == color;

  @override
  int get hashCode => Object.hash(name, color);
}
