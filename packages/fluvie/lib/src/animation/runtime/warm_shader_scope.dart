import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Publishes the fragment-shader programs the pre-pass compiled, keyed by
/// asset, so a `ShaderEffect` deep in the tree can paint synchronously.
///
/// The shader analogue of `ImageResolverScope`: all of the IO happens before
/// frame 0 and the lookup below is a pure synchronous map read, which is what
/// keeps capture free of async-in-frame.
///
/// It carries *programs*, not shaders, deliberately. A `ui.FragmentShader`
/// owns mutable uniform slots that paint rewrites on every frame, so handing
/// one instance to two elements that use the same asset would let the second
/// element's uniforms leak into the first element's draw. Each element derives
/// its own shader from the shared program, which is the part that is expensive
/// to compile and safe to share.
final class WarmShaderScope extends InheritedWidget {
  /// Publishes [programs] (asset to compiled program) over [child].
  const WarmShaderScope({required this.programs, required super.child, super.key});

  /// The compiled programs, keyed by the asset the author wrote.
  final Map<String, ui.FragmentProgram> programs;

  /// The program compiled for [asset], or `null` when the pre-pass did not warm
  /// it — the painter then reports the unwarmed asset by name.
  ui.FragmentProgram? programFor(String asset) => programs[asset];

  /// The nearest scope above [context], or `null` when nothing warmed shaders
  /// (a composition with no shader mounts no scope at all).
  static WarmShaderScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WarmShaderScope>();

  @override
  bool updateShouldNotify(WarmShaderScope oldWidget) => !identical(oldWidget.programs, programs);
}
