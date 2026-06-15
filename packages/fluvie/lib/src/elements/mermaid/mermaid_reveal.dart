import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/reveal/reveal_progress.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:meta/meta.dart' show immutable;

/// How a `Mermaid` diagram reveals itself over its window: all at once, by
/// fading its nodes in, or by drawing its edges in.
///
/// A sealed value type, mirroring `CodeReveal`: the `Mermaid` constructor stays
/// one `reveal:` parameter wide and the reveal math is one pure function,
/// [mermaidRevealOpacity]. The diagram is rasterized once before the frame loop;
/// the reveal drives a per-frame opacity over that single raster (per-SVG-node
/// reveal is a later follow-up), so it never re-rasterizes. Each timed variant
/// carries a [Time] that resolves against the element window, so a relative
/// window scales with the scene.
@immutable
sealed class MermaidReveal {
  const MermaidReveal();

  /// Fades the whole diagram in over [window] frames.
  const factory MermaidReveal.fadeNodes(Time window) = FadeNodesReveal;

  /// Draws the diagram in over [window] frames (a whole-raster fade today;
  /// per-edge stroke reveal is a later follow-up).
  const factory MermaidReveal.drawEdges(Time window) = DrawEdgesReveal;

  /// Shows the whole diagram immediately (the default).
  static const MermaidReveal none = NoMermaidReveal._();
}

/// The [MermaidReveal.none] variant: the diagram is fully visible from frame 0.
final class NoMermaidReveal extends MermaidReveal {
  const NoMermaidReveal._();

  @override
  bool operator ==(Object other) => other is NoMermaidReveal;

  @override
  int get hashCode => (NoMermaidReveal).hashCode;

  @override
  String toString() => 'MermaidReveal.none';
}

/// The [MermaidReveal.fadeNodes] variant: a whole-raster fade over [window].
final class FadeNodesReveal extends MermaidReveal {
  /// Creates a fade-in over [window] frames.
  const FadeNodesReveal(this.window);

  /// How long the fade takes; resolved against the element window.
  final Time window;

  @override
  bool operator ==(Object other) => other is FadeNodesReveal && other.window == window;

  @override
  int get hashCode => Object.hash(FadeNodesReveal, window);

  @override
  String toString() => 'MermaidReveal.fadeNodes($window)';
}

/// The [MermaidReveal.drawEdges] variant: a whole-raster draw-in over [window].
final class DrawEdgesReveal extends MermaidReveal {
  /// Creates a draw-in over [window] frames.
  const DrawEdgesReveal(this.window);

  /// How long the draw-in takes; resolved against the element window.
  final Time window;

  @override
  bool operator ==(Object other) => other is DrawEdgesReveal && other.window == window;

  @override
  int get hashCode => Object.hash(DrawEdgesReveal, window);

  @override
  String toString() => 'MermaidReveal.drawEdges($window)';
}

/// The diagram opacity for [reveal] at [frame] within [scope] — a pure function
/// over the frame clock.
///
/// [MermaidReveal.none] is always full (`1.0`); the timed variants ramp `0 -> 1`
/// across their window by delegating to [revealProgress], which resolves the
/// [Time] against [scope] (so `0.6.relative` measures the element's own window)
/// and clamps the result to `[0, 1]`. Both timed variants share the same fade
/// math, so none can drift from `Code`'s reveal arithmetic.
double mermaidRevealOpacity(MermaidReveal reveal, int frame, TimeScopeData scope) =>
    switch (reveal) {
      NoMermaidReveal() => 1.0,
      FadeNodesReveal(:final window) => revealProgress(frame, scope, window),
      DrawEdgesReveal(:final window) => revealProgress(frame, scope, window),
    };
