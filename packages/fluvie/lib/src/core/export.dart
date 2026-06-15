import 'package:fluvie/src/core/quality.dart';
import 'package:meta/meta.dart';

/// The still-image format of an `Export.imageSequence`.
enum ImageFormat {
  /// Lossless PNG, one file per frame — the compositing-pipeline default.
  png,
}

/// What the render should produce: an MP4, a GIF, an image sequence,
/// or an alpha-capable overlay.
///
/// This is pure config data; the render pipeline dispatches on it at render.
/// A `Video(export: ...)` carries the value verbatim —
/// declaring it changes nothing about preview or capture. Exports are
/// value-equal within a variant, so configs can be compared and cached.
@immutable
final class Export {
  // Reason: const-ctor artifacts. export_test pins each variant mode, equality,
  // and toString. The VM does not instrument the const literals.
  // coverage:ignore-start
  const Export._(this.mode, {this.quality, this.gifFps, this.imageFormat});

  /// An H.264 MP4 at [quality] — the default share-anywhere container.
  const Export.mp4({Quality quality = Quality.high}) : this._(ExportMode.mp4, quality: quality);

  /// An animated GIF sampled at [fps] (GIFs rarely need the full frame rate).
  const Export.gif({int fps = 15}) : this._(ExportMode.gif, gifFps: fps);

  /// One still per frame in [format] — for compositing pipelines.
  const Export.imageSequence({ImageFormat format = ImageFormat.png})
    : this._(ExportMode.imageSequence, imageFormat: format);

  /// An alpha-preserving overlay export (WebM/ProRes).
  const Export.transparent() : this._(ExportMode.transparent);
  // coverage:ignore-end

  /// The variant of this export, for the render pipeline's mode dispatch
  /// and the inspector. The factory used picks the mode:
  /// `Export.mp4()` is [ExportMode.mp4], and so on.
  final ExportMode mode;

  /// The encode quality of an [Export.mp4]; `null` on every other variant.
  final Quality? quality;

  /// The sample rate of an [Export.gif]; `null` on every other variant.
  final int? gifFps;

  /// The frame format of an [Export.imageSequence]; `null` on every other
  /// variant.
  final ImageFormat? imageFormat;

  @override
  bool operator ==(Object other) =>
      other is Export &&
      other.mode == mode &&
      other.quality == quality &&
      other.gifFps == gifFps &&
      other.imageFormat == imageFormat;

  @override
  int get hashCode => Object.hash(Export, mode, quality, gifFps, imageFormat);

  @override
  String toString() => switch (mode) {
    ExportMode.mp4 => 'Export.mp4(quality: $quality)',
    ExportMode.gif => 'Export.gif(fps: $gifFps)',
    ExportMode.imageSequence => 'Export.imageSequence(format: $imageFormat)',
    ExportMode.transparent => 'Export.transparent()',
  };
}

/// The four [Export] variants the render pipeline dispatches on.
/// Stable, public discriminator: the names are
/// the public surface the renderer and the inspector branch on.
enum ExportMode {
  /// An H.264 MP4 ([Export.mp4]).
  mp4,

  /// An animated GIF ([Export.gif]).
  gif,

  /// A lossless still per frame ([Export.imageSequence]).
  imageSequence,

  /// An alpha-preserving overlay ([Export.transparent]).
  transparent,
}
