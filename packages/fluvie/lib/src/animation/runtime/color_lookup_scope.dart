import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Publishes the colour lookup images the pre-pass baked — curve strips and
/// flattened LUT cubes — keyed by content, so a colour effect deep in the
/// tree can bind its sampler synchronously.
///
/// The image analogue of `WarmShaderScope`: building a `ui.Image` from bytes
/// is asynchronous, so it happens before frame 0 like every other resolve,
/// and the lookup below is a pure synchronous map read. Images are safely
/// shared across elements — unlike a `FragmentShader`, an image carries no
/// mutable slots.
final class ColorLookupScope extends InheritedWidget {
  /// Publishes [lookups] (content key to baked image) over [child].
  const ColorLookupScope({required this.lookups, required super.child, super.key});

  /// The baked images, keyed by `curves:<digest>` or `lut:<asset>`.
  final Map<String, ui.Image> lookups;

  /// The image baked for [key], or `null` when the pre-pass did not bake it —
  /// the painter then reports the missing lookup by key.
  ui.Image? lookupFor(String key) => lookups[key];

  /// The nearest scope above [context], or `null` when nothing baked
  /// lookups (a composition with no colour effect mounts no scope at all).
  static ColorLookupScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ColorLookupScope>();

  @override
  bool updateShouldNotify(ColorLookupScope oldWidget) => !identical(oldWidget.lookups, lookups);
}
