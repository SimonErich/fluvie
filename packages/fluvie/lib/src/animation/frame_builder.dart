/// @docImport 'package:fluvie/src/elements/counter.dart';
/// @docImport 'package:fluvie/src/rendering/runtime/frame_provider.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/runtime/frame_context.dart';
import 'package:meta/meta.dart';

/// The escape hatch: when no preset fits, drop to a builder with
/// the resolved frame, progress, fps, scope, seeded noise, and analysed audio
/// and paint anything.
///
/// It reads the frame clock the same way [Counter] does — a plain
/// `StatelessWidget` whose `build` rebuilds exactly when the [FrameProvider]
/// frame changes — and hands the [builder] a live [FrameContext] resolved from
/// the enclosing scopes. Everything the builder reads is deterministic (the
/// frame is the only clock; noise and audio are precomputed), so a
/// `FrameBuilder` is as cacheable and golden-stable as any preset.
///
/// ```dart
/// FrameBuilder((ctx) {
///   final p = ctx.progress;            // 0..1 across this element's window
///   return CustomPaint(painter: MyViz(progress: p));
/// });
/// ```
///
/// `@experimental`: the escape-hatch surface may still change.
@experimental
final class FrameBuilder extends StatelessWidget {
  /// Creates a frame-driven builder that paints from a live [FrameContext].
  const FrameBuilder(this.builder, {super.key});

  /// Called every frame with the resolved [FrameContext]; returns the widget to
  /// render for that frame.
  final Widget Function(FrameContext ctx) builder;

  @override
  Widget build(BuildContext context) => builder(FrameContext(context));
}
