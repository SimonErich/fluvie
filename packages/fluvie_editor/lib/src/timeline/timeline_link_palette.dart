import 'dart:ui' show Color;

import 'package:meta/meta.dart';

/// The colors a slide timeline paints its trigger links with: one for the
/// end-anchored kinds (`whenEnds` and `previous`, which chain off an end)
/// and one for `whenStarts`.
@immutable
final class TimelineLinkPalette {
  /// Creates the palette.
  const TimelineLinkPalette({required this.ends, required this.starts});

  /// The connector color of `whenEnds` and `previous` links.
  final Color ends;

  /// The connector color of `whenStarts` links.
  final Color starts;

  @override
  bool operator ==(Object other) =>
      other is TimelineLinkPalette && other.ends == ends && other.starts == starts;

  @override
  int get hashCode => Object.hash(TimelineLinkPalette, ends, starts);
}
