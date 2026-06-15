import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/animation_effect.dart';
import 'package:fluvie/src/animation/runtime/reactive_scope.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/audio_band.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

/// How a [ReactiveEffect] maps band energy to a transform.
enum ReactiveMode {
  /// Scales only the child's Y axis — the spectrum-bar look.
  scaleY,

  /// Scales the child uniformly — the on-beat pulse.
  pulse,
}

/// The one internal effect behind every spectrum-reactive preset: it reads a
/// precomputed `BandTable` from the nearest [ReactiveScope] and scales its
/// child by the current frame's band energy.
///
/// It ignores `progress` entirely — a reactive animation is driven by the audio
/// analysis, not the element's window — and instead reads the frame clock and
/// looks up `energyAt(frame, band) * gain`, applying it per [mode]. The lookup
/// is pure (never live audio), so the render stays deterministic.
///
/// With no scope the behaviour splits on the render mode (mirroring the resolved
/// media discipline): a capture without a precomputed table is a determinism
/// violation and throws a [FluvieRenderException] naming the band and the
/// precompute pass; a live preview falls back to the neutral (energy 0) state,
/// so the element sits at its natural size.
final class ReactiveEffect implements AnimationEffect {
  /// Creates a reactive effect reading [band] (optionally scoped to [track]),
  /// scaled by [gain], applied as [mode].
  const ReactiveEffect({
    required this.mode,
    required this.band,
    this.gain = 1.0,
    this.track,
  });

  /// How the band energy maps to a transform.
  final ReactiveMode mode;

  /// The frequency band whose energy drives the effect.
  final AudioBand band;

  /// The multiplier on the `[0, 1]` band energy (`1.5` reaches 150% at a peak).
  final double gain;

  /// The audio track this reacts to, or `null` for the default (master) table.
  final Anchor? track;

  @override
  Widget build(Widget child, double progress) =>
      _ReactiveView(mode: mode, band: band, gain: gain, track: track, child: child);

  @override
  String toString() => 'ReactiveEffect(${mode.name}, band: ${band.name}, gain: $gain)';
}

/// Reads the frame clock and the reactive scope to scale [child] by the current
/// frame's band energy.
class _ReactiveView extends StatelessWidget {
  const _ReactiveView({
    required this.mode,
    required this.band,
    required this.gain,
    required this.track,
    required this.child,
  });

  final ReactiveMode mode;
  final AudioBand band;
  final double gain;
  final Anchor? track;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final table = ReactiveScope.tableFor(context, track);
    final energy = _energy(context, table);
    final amount = energy * gain;
    return switch (mode) {
      ReactiveMode.scaleY => Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(1, 1 + amount, 1),
        child: child,
      ),
      ReactiveMode.pulse => Transform.scale(scale: 1 + amount, child: child),
    };
  }

  /// The band energy at the current frame, or `0` for the neutral fallback —
  /// throwing only when a capture has no precomputed table.
  double _energy(BuildContext context, BandTable? table) {
    if (table == null) {
      if (RenderModeContext.isCapture(context)) {
        throw FluvieRenderException(
          'A reactive animation on AudioBand.${band.name} cannot render in '
          'capture without a precomputed BandTable. Mount a ReactiveScope and '
          'analyse the audio track in the precompute pass before the frame loop.',
        );
      }
      return 0;
    }
    final frame = FrameProvider.of(context).frame;
    return table.energyAt(frame, band);
  }
}
