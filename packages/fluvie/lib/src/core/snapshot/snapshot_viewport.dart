import 'package:meta/meta.dart';

/// The fixed pixel box a `WebView`/`Html` snapshot is laid out and captured in.
///
/// A snapshot must be deterministic, so its size is declared up front, never
/// discovered from the live window. [width] and [height] are logical pixels;
/// [deviceScale] (default `1.0`) multiplies them to the raster's physical pixel
/// dimensions ([pixelWidth]/[pixelHeight]). All three must be positive — a zero
/// or negative dimension cannot produce a raster.
///
/// `WebView` and `Html` are named in prose, not as doc links, because they live
/// in layers above `core` and a link would invert the layering.
@immutable
final class SnapshotViewport {
  /// Creates a viewport [width]x[height] logical pixels at [deviceScale]
  /// (default `1.0`). All three must be positive.
  const SnapshotViewport({required this.width, required this.height, this.deviceScale = 1.0})
    : assert(width > 0, 'width must be positive'),
      assert(height > 0, 'height must be positive'),
      assert(deviceScale > 0, 'deviceScale must be positive');

  /// The logical width of the viewport, in pixels.
  final int width;

  /// The logical height of the viewport, in pixels.
  final int height;

  /// The device pixel ratio applied to logical dimensions when rasterizing.
  final double deviceScale;

  /// The physical raster width: [width] scaled by [deviceScale], rounded.
  int get pixelWidth => (width * deviceScale).round();

  /// The physical raster height: [height] scaled by [deviceScale], rounded.
  int get pixelHeight => (height * deviceScale).round();

  @override
  bool operator ==(Object other) =>
      other is SnapshotViewport &&
      other.width == width &&
      other.height == height &&
      other.deviceScale == deviceScale;

  @override
  int get hashCode => Object.hash(SnapshotViewport, width, height, deviceScale);

  @override
  String toString() => 'SnapshotViewport(${width}x$height @${deviceScale}x)';
}
