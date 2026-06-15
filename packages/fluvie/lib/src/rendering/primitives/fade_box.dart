import 'package:flutter/widgets.dart';

/// The render-safe fade primitive: one named place where
/// every Fluvie fade becomes pixels.
///
/// Paint-equivalent to a raw [Opacity] by construction:
///
/// - at exactly `1.0` it mounts nothing — the child paints directly, exactly
///   as [Opacity] at 1 would paint it (and as the keyframe applier paints an
///   element with no opacity at all);
/// - everywhere else it mounts a single [Opacity] with [opacity] clamped
///   into `[0, 1]` (spring overshoot can push a composed keyframe past the
///   bounds mid-flight);
/// - at `0` the [Opacity] holds the layout slot while `RenderOpacity` skips
///   painting entirely — hidden elements never collapse the layout.
///
/// The keyframe applier and `MotionTarget`'s collect-pass placeholder build
/// this instead of [Opacity] directly, so future fade upgrades (such as a
/// shader fade) land in exactly one widget.
final class FadeBox extends StatelessWidget {
  /// Fades [child] to [opacity] (`0` hidden, `1` fully painted).
  const FadeBox({required this.opacity, required this.child, super.key});

  /// The fade value as given — clamped into `[0, 1]` only at build time, so
  /// probes and debuggers see the raw composed number.
  final double opacity;

  /// The element being faded.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (opacity == 1.0) return child;
    return Opacity(opacity: opacity.clamp(0.0, 1.0), child: child);
  }
}
