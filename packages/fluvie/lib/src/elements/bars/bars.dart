import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/runtime/reactive_scope.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/audio_band.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/elements/bars/render/bars_painter.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/theme/build_context_tokens.dart';

/// A spectrum-bar visualizer driven by a precomputed audio band table — an
/// intrinsic, frame-driven element.
///
/// It reads `energyAt(frame, [band])` from the nearest `ReactiveScope` each
/// frame and paints [count] bars whose heights track that energy times [gain].
/// The band's energy is spread across the bars by a fixed, deterministic
/// sub-band profile (a golden-angle bump), so even many bars read as a spectrum
/// rather than one flat block while staying byte-identical across runs. [track]
/// scopes it to one `Audio.track` anchor; `null` reads the master mix.
///
/// ```dart
/// Bars(count: 24, band: AudioBand.bass).animate([Animation.fadeIn()])
/// ```
///
/// Transforms and effects come through `.animate()` only — the constructor
/// takes content parameters and nothing else. Bars are colored from
/// `context.fluvie`. [shared] wraps the result in a `SharedElement` for a hero
/// morph across a scene boundary. Like every reactive element it needs a
/// `ReactiveScope` in capture (the precompute pass); a live preview with no
/// scope renders flat (energy 0) rather than throwing.
final class Bars extends StatelessWidget {
  /// Creates a [count]-bar visualizer of [band] (scoped to [track]) scaled by
  /// [gain].
  const Bars({
    this.count = 24,
    this.band = AudioBand.bass,
    this.track,
    this.gain = 1.0,
    this.shared,
    super.key,
  });

  /// How many bars to paint.
  final int count;

  /// The frequency band whose energy drives the bar heights.
  final AudioBand band;

  /// The audio track this reacts to, or `null` for the master mix.
  final Anchor? track;

  /// The multiplier on the `[0, 1]` band energy.
  final double gain;

  /// An optional hero anchor: when non-null the bars morph across the boundary
  /// they share with the same anchor in the adjacent scene. `null` mounts no
  /// `SharedElement`.
  final Anchor? shared;

  @override
  Widget build(BuildContext context) {
    final table = ReactiveScope.tableFor(context, track);
    final energy = _energy(context, table);
    final heights = barHeights(count: count, energy: energy, gain: gain);
    final painter = BarsPainter(heights: heights, color: context.fluvie.palette.colorAt(0));
    return wrapShared(shared, CustomPaint(painter: painter, size: Size.infinite));
  }

  /// The current frame's energy for [band], or `0` for the neutral fallback —
  /// throwing only when a capture has no precomputed table.
  double _energy(BuildContext context, BandTable? table) {
    if (table == null) {
      if (RenderModeContext.isCapture(context)) {
        throw FluvieRenderException(
          'Bars on AudioBand.${band.name} cannot render in capture without a '
          'precomputed BandTable. Mount a ReactiveScope and analyse the audio '
          'track in the precompute pass before the frame loop.',
        );
      }
      return 0;
    }
    return table.energyAt(FrameProvider.of(context).frame, band);
  }

  /// The per-bar fractional heights for [count] bars at the given [energy] and
  /// [gain] — pure and deterministic, exposed so the painter and tests share
  /// one source of truth.
  ///
  /// Each bar's height is `energy · gain · profile(i)`, where the profile is a
  /// fixed golden-angle bump that varies bar to bar (a spectrum shape, not a
  /// flat block) yet is identical across runs. A single bar uses a flat profile.
  static List<double> barHeights({
    required int count,
    required double energy,
    required double gain,
  }) {
    final scaled = energy * gain;
    return [for (var i = 0; i < count; i++) scaled * _profile(i, count)];
  }

  /// The deterministic `[0, 1]` weight of bar [i] of [count].
  static double _profile(int i, int count) {
    if (count <= 1) return 1;
    // A golden-angle phase gives a non-repeating yet fixed bar-to-bar variation.
    final phase = i * 2.399963229728653; // 2π / φ²
    return 0.55 + 0.45 * (0.5 + 0.5 * math.sin(phase));
  }
}
