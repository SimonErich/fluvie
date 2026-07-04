import 'package:flutter/painting.dart' show Alignment;
import 'package:meta/meta.dart';

/// Where a caption sits on the canvas: an [alignment] plus a [safeArea] inset
/// in logical pixels.
///
/// This is the explicit value type behind the `Align.thirds.bottom`
/// shorthand. Fluvie ships named factories ([CaptionPosition.bottomThird],
/// [CaptionPosition.topThird], [CaptionPosition.center],
/// [CaptionPosition.custom]) rather than a generic alignment grammar, so a
/// caption reads as a position, not an offset. The [safeArea] keeps the text
/// clear of the canvas edge (and platform UI) by inset logical pixels.
/// Value-equal so a styled track caches stably across builds.
@immutable
final class CaptionPosition {
  /// The lower third of the canvas — the default caption placement.
  const CaptionPosition.bottomThird() : alignment = const Alignment(0, 1 / 3), safeArea = 64;

  // coverage:ignore-start const ctor artifacts caption_values_coverage_test pins each preset alignment and safe area
  /// The upper third of the canvas.
  const CaptionPosition.topThird() : alignment = const Alignment(0, -1 / 3), safeArea = 64;

  /// Dead center, with no safe-area inset.
  const CaptionPosition.center() : alignment = Alignment.center, safeArea = 0;

  /// An explicit [alignment] with an optional [safeArea] inset.
  const CaptionPosition.custom(this.alignment, {this.safeArea = 0});
  // coverage:ignore-end

  /// Where on the canvas the caption block aligns.
  final Alignment alignment;

  /// The inset (in logical pixels) kept clear between the caption block and the
  /// nearest canvas edge along the alignment axis.
  final double safeArea;

  @override
  bool operator ==(Object other) =>
      other is CaptionPosition && other.alignment == alignment && other.safeArea == safeArea;

  @override
  int get hashCode => Object.hash(CaptionPosition, alignment, safeArea);

  @override
  String toString() => 'CaptionPosition($alignment, safeArea: $safeArea)';
}
