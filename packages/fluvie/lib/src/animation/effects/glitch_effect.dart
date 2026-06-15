import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/animation/effects/chromatic_effect.dart';
import 'package:fluvie/src/animation/runtime/noise_scope.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/noise/noise_source.dart';
import 'package:fluvie/src/core/noise/value_noise.dart';

/// The effect behind `Animation.glitchIn`: a brief digital glitch that
/// resolves to the natural frame.
///
/// A pixel post-effect — it slices the child into horizontal bands, shifts
/// each band sideways by a seeded jitter, and overlays a chromatic split. Both
/// the jitter (per-band, from [NoiseSource]) and the split shrink to zero as
/// `progress` reaches `1`, so the effect lands exactly on the untouched child.
/// [from] seeds the slice direction (left/right bias). Everything is a pure
/// function of `progress`, [from], and the seed, so two pumps paint identical
/// pixels and the same seed always glitches the same way. The slices use
/// [ClipRect]/[Transform], capture-safe through `RepaintBoundary.toImage`.
final class GlitchEffect implements PixelAnimationEffect {
  /// Creates a glitch whose slices bias toward [from] (defaults to
  /// [Edge.left]), sampling jitter from [noise] (the const [ValueNoise] stub).
  const GlitchEffect({this.from = Edge.left, NoiseSource noise = const ValueNoise()})
    : _noise = noise; // ignore: prefer_initializing_formals — public arg `noise`, private field

  /// The edge the slice jitter biases toward; defaults to [Edge.left].
  final Edge from;

  final NoiseSource _noise;

  /// How many horizontal bands the frame is sliced into.
  static const int _slices = 9;

  /// The widest a band shifts at progress 0, in logical pixels.
  static const double _maxShift = 14;

  @override
  Widget build(Widget child, double progress) {
    if (progress >= 1) return child;
    final intensity = (1 - progress).clamp(0.0, 1.0);
    final bias = from == Edge.right ? 1.0 : -1.0;
    final split = intensity * 4;
    // A mounted NoiseScope wins; otherwise the effect's own source (the const
    // ValueNoise() default), so a tree with no scope jitters byte-identically.
    return Builder(
      builder: (context) {
        final noise = NoiseScope.maybeOf(context) ?? _noise;
        return Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < _slices; i++) _band(child, i, intensity, bias, noise),
            IgnorePointer(
              child: Opacity(
                opacity: 0.6 * intensity,
                child: ChromaticEffect(split).build(child, 0),
              ),
            ),
          ],
        );
      },
    );
  }

  /// One horizontal band of the child, clipped to its slice and shifted by a
  /// seeded jitter scaled by [intensity] toward [bias], sampled from [noise].
  Widget _band(Widget child, int index, double intensity, double bias, NoiseSource noise) {
    // A signed jitter in [-1, 1] from the per-slice seed, biased by the edge.
    final jitter = (noise.valueForSeed('glitch-$index') * 2 - 1) * bias;
    return ClipRect(
      clipper: _BandClipper(index, _slices),
      child: Transform.translate(
        offset: Offset(jitter * _maxShift * intensity, 0),
        child: child,
      ),
    );
  }

  @override
  String toString() => 'GlitchEffect(from: ${from.name})';
}

/// Clips to one of [count] equal horizontal bands (the [index]th from the top).
final class _BandClipper extends CustomClipper<Rect> {
  const _BandClipper(this.index, this.count);

  final int index;
  final int count;

  @override
  Rect getClip(Size size) {
    final height = size.height / count;
    return Rect.fromLTWH(0, index * height, size.width, height);
  }

  @override
  bool shouldReclip(_BandClipper oldClipper) =>
      oldClipper.index != index || oldClipper.count != count;
}
