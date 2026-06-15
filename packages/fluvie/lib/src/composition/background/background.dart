import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/runtime/gradient_shift_scope.dart';
import 'package:fluvie/src/animation/runtime/keyframe_scope.dart';
import 'package:fluvie/src/core/media/media_carrier.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/elements/runtime/clip_painter.dart';
import 'package:fluvie/src/media/runtime/resolved_image.dart';

part 'background_fills.dart';
part 'background_media.dart';
part 'background_textures.dart';

/// A full-canvas backdrop — one widget, seven looks.
///
/// A `Background` is a normal element: pass it to `Scene(background:)` for a
/// static backdrop, or mount it as a child, tag it with an `Anchor`, and
/// `.animate()` it like anything else — that is the gradient-shift trigger of
/// the quickstart. It always expands to fill its parent (a
/// [SizedBox.expand], never a `Positioned.fill`, so `.animate()`'s wrapper can
/// sit above it anywhere).
///
/// The fill variants consume the animation system's data channels:
/// [Background.color] paints the composed keyframe color when an
/// `Animation.color` runs above it, and
/// [Background.gradient]/[Background.radial] lerp their base colors pairwise
/// toward an enclosing gradient shift's targets.
/// [Background.noise] and [Background.vhs] are deterministic seeded textures.
/// [Background.image] paints a pre-resolved image synchronously
/// from the enclosing `ImageResolverScope` in capture — through
/// the shared `ResolvedImage`, the same path the `Image` element uses.
/// [Background.video] paints a pre-resolved clip frame the same way the `Clip`
/// element does: through `ClipPainter`, which resamples the source to the
/// current composition frame.
final class Background extends StatelessWidget implements MediaCarrier {
  /// A solid [color] fill.
  ///
  /// When an `Animation.color` (or any keyframe carrying a color) runs on
  /// this background, the published per-frame color wins over [color] — the
  /// first real consumer of the composed-keyframe color channel.
  Background.color(Color color, {Key? key}) : this._(_ColorFill(color), key: key);

  /// A linear gradient through [colors], running [begin] → [end]
  /// (top-left → bottom-right by default).
  ///
  /// Under an `Animation.gradientShift`, every base color lerps pairwise
  /// toward the shift's target list (which must have the same length).
  Background.gradient(
    List<Color> colors, {
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
    Key? key,
  }) : this._(
         _LinearGradientFill(colors, begin: begin, end: end),
         key: key,
       );

  /// A center-out radial gradient through [colors]; shifts like
  /// [Background.gradient].
  Background.radial(List<Color> colors, {Key? key}) : this._(_RadialGradientFill(colors), key: key);

  /// A still image asset [source] (a bundle key), scaled by [fit].
  ///
  /// In capture the image is pre-resolved before the frame loop and painted
  /// synchronously from the enclosing `ImageResolverScope`; a preview app
  /// falls back to Flutter's async asset path.
  Background.image(String source, {BoxFit fit = BoxFit.cover, Key? key})
    : this._(_ImageBackdrop(source, fit: fit), key: key);

  /// A video asset [source] (a bundle key), scaled to cover the canvas.
  ///
  /// In capture the source is pre-resolved as a *clip* (probed and
  /// frame-extracted before the frame loop) and painted through
  /// `ClipPainter`, which resamples the source to the current composition frame
  /// — the same path the `Clip` element uses. A preview paints a placeholder,
  /// where determinism does not bind.
  Background.video(String source, {Key? key}) : this._(_VideoBackdrop(source), key: key);

  /// A deterministic grayscale value-noise texture; [scale] (> 0) multiplies
  /// the cell size, so larger values mean coarser grain.
  Background.noise({double scale = 1, Key? key}) : this._(_NoiseTexture(scale), key: key);

  /// A deterministic VHS-style texture: scanlines over drifting static bands.
  const Background.vhs({Key? key}) : this._(const _VhsTexture(), key: key);

  const Background._(this._spec, {super.key});

  /// What this background paints — one variant of the sealed spec.
  final _BackgroundSpec _spec;

  /// The media this background resolves, or `null` for a fill/texture variant.
  /// The collect pass (`collectMediaSources`) reads it to gather
  /// `Background.image`/`.video` sources from the declared tree without
  /// mounting the widget.
  @override
  MediaSource? get mediaSource => _spec.mediaSource;

  /// A `Background` declares no snapshot — its media (if any) is a loaded
  /// `image`/`video`, not a computed one.
  @override
  SnapshotSource? get snapshotSource => null;

  @override
  Widget build(BuildContext context) => SizedBox.expand(child: _spec.build(context));
}

/// One `Background` variant's data and paint logic. Private by design: the
/// public surface is exactly the constructors on [Background].
sealed class _BackgroundSpec {
  const _BackgroundSpec();

  /// The media this variant resolves, or `null` for the fill/texture variants.
  MediaSource? get mediaSource => null;

  /// Builds the variant's content; the enclosing [Background] expands it.
  Widget build(BuildContext context);
}
