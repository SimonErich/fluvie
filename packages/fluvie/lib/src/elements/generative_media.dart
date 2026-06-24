import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/errors/fluvie_generative_exception.dart';
import 'package:fluvie/src/core/media/clip_audio.dart';
import 'package:fluvie/src/core/media/generative_carrier.dart';
import 'package:fluvie/src/core/media/generative_kind.dart';
import 'package:fluvie/src/core/media/generative_source.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/elements/runtime/clip_painter.dart';
import 'package:fluvie/src/media/runtime/generative_resolver_scope.dart';
import 'package:fluvie/src/media/runtime/resolved_image.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

/// Paints a produced visual [GenerativeSource] (image or video) — the
/// provider-agnostic element every generative-image/video widget builds.
///
/// It declares its [source] through [GenerativeCarrier] so the prerender pass
/// produces it before the frame loop, then resolves the produced file-backed
/// `MediaSource` from the [GenerativeResolverScope] and delegates to the same
/// runtime painters as a hand-written `Image`/`Clip` ([ResolvedImage] /
/// [ClipPainter]) — so a generated asset paints exactly like a local one.
///
/// With no scope the behaviour splits on the render mode, like `ResolvedImage`:
/// a capture without a resolver is a determinism violation and throws a
/// [FluvieGenerativeException]; a live preview shows [placeholder] (generation
/// runs only in the pre-pass, never mid-frame).
///
/// `GenerativeResolverScope`, the provider widgets, and `GenerativeAudio` are
/// named in prose, not as doc links, because they live in other layers.
final class GenerativeMedia extends StatelessWidget implements GenerativeCarrier {
  /// Paints [source] scaled by [fit]; [trim] trims a video in source time and
  /// [audio] is the embedded-audio policy for a generated video.
  const GenerativeMedia({
    required this.source,
    this.fit,
    this.trim,
    this.audio = const ClipAudio.included(),
    this.placeholder,
    super.key,
  });

  /// The generative media to produce and paint (must be a visual kind).
  final GenerativeSource source;

  /// How the asset scales into its box; `null` lets the painter pick its default.
  final BoxFit? fit;

  /// The source-time trim for a generated video; ignored for an image.
  final TimeRange? trim;

  /// The embedded-audio policy for a generated video (for example Veo 3, which
  /// outputs an audio track); ignored for an image. Defaults to keeping the
  /// track in the mix, delayed to the clip's scene window.
  final ClipAudio audio;

  /// Shown in a live preview while no resolver is in scope; defaults to an
  /// expanding empty box.
  final Widget? placeholder;

  @override
  GenerativeSource? get generativeSource => source;

  @override
  Widget build(BuildContext context) {
    final resolver = GenerativeResolverScope.maybeOf(context);
    if (resolver != null) {
      return switch (source.kind) {
        GenerativeKind.image => ResolvedImage(source: resolver.mediaFor(source), fit: fit),
        GenerativeKind.video => ClipPainter(
          source: resolver.mediaFor(source),
          trim: trim,
          fit: fit,
        ),
        _ => throw FluvieGenerativeException(
          'GenerativeMedia paints only visual sources; "$source" is audio — '
          'declare audio with GenerativeAudio instead.',
        ),
      };
    }
    if (RenderModeContext.isCapture(context)) {
      throw FluvieGenerativeException(
        'Generative media "$source" cannot render in capture without a '
        'GenerativeResolverScope. Install the fluvie_ai generative resolver and '
        'include the source in the collect pass (collectGenerativeSources) '
        'before the frame loop.',
      );
    }
    return placeholder ?? const SizedBox.expand();
  }
}
