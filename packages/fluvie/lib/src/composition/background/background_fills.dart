part of 'background.dart';

/// `Background.color`: paints the composed keyframe color when one is published
/// above it, the constructor color otherwise — a consumer of the
/// [KeyframeScope] channel.
final class _ColorFill extends _BackgroundSpec {
  const _ColorFill(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: KeyframeScope.maybeOf(context)?.color ?? color);
}

/// `Background.gradient`: a linear gradient that lerps toward an
/// enclosing gradient shift's targets.
final class _LinearGradientFill extends _BackgroundSpec {
  const _LinearGradientFill(this.colors, {required this.begin, required this.end});

  final List<Color> colors;
  final Alignment begin;
  final Alignment end;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: _shiftedColors(colors, GradientShiftScope.maybeOf(context)),
        begin: begin,
        end: end,
      ),
    ),
  );
}

/// `Background.radial`: a center-out radial gradient that shifts like
/// the linear one.
final class _RadialGradientFill extends _BackgroundSpec {
  const _RadialGradientFill(this.colors);

  final List<Color> colors;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        colors: _shiftedColors(colors, GradientShiftScope.maybeOf(context)),
      ),
    ),
  );
}

/// The pairwise lerp: every base color travels toward its same-index
/// shift target at the scope's progress (clamped — overshooting springs hold
/// the endpoints, colors never extrapolate). No shift, no change.
List<Color> _shiftedColors(List<Color> base, GradientShiftScope? shift) {
  if (shift == null) return base;
  assert(
    shift.colors.length == base.length,
    'gradientShift carries ${shift.colors.length} target color(s) for a '
    '${base.length}-color background — the to: list must pair up with the '
    'base colors index by index.',
  );
  final t = shift.progress.clamp(0.0, 1.0);
  return [for (var i = 0; i < base.length; i++) Color.lerp(base[i], shift.colors[i], t)!];
}
