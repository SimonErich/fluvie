import 'dart:typed_data';

import 'package:meta/meta.dart';

/// The decoded-ready output of one `SnapshotService.rasterize` call: the
/// raster's encoded [bytes], the [contentHash] that keys the
/// snapshot cache, and the pixel [width]/[height].
///
/// The async snapshot pipeline produces a `SnapshotRaster`; the resolver decodes
/// its [bytes] once to a `ui.Image` and serves that synchronously during the
/// frame loop, so a snapshot becomes "just another resolved media". Equality
/// keys on the [contentHash] (and dimensions), not the buffer identity: two
/// runs that hash to the same content are the same raster.
///
/// `SnapshotService` is named in prose, not as a doc link, because it lives in a
/// layer above `core`.
@immutable
final class SnapshotRaster {
  /// Creates a raster carrying [bytes], its [contentHash] and pixel
  /// [width]/[height] (both must be positive).
  // Not const: it carries a mutable Uint8List buffer produced at rasterize
  // time, so a const constructor is impossible here.
  // ignore: prefer_const_constructors_in_immutables
  SnapshotRaster({
    required this.bytes,
    required this.contentHash,
    required this.width,
    required this.height,
  }) : assert(width > 0, 'width must be positive'),
       assert(height > 0, 'height must be positive');

  /// The encoded raster bytes (for example PNG), decoded once before frame 0.
  final Uint8List bytes;

  /// The content hash of the rasterized pixels, produced by the service.
  ///
  /// It is carried for the frame-cache / render-digest integration, so
  /// a change in a snapshot's pixels can bust the frame cache. The in-memory
  /// repository cache keys on the `SnapshotSource` declaration `cacheKey`
  /// instead, so this field is intentionally not read by
  /// it; it is part of the raster contract every service produces.
  final String contentHash;

  /// The raster width in pixels.
  final int width;

  /// The raster height in pixels.
  final int height;

  @override
  bool operator ==(Object other) =>
      other is SnapshotRaster &&
      other.contentHash == contentHash &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(SnapshotRaster, contentHash, width, height);

  @override
  String toString() => 'SnapshotRaster(${width}x$height, hash: $contentHash)';
}
