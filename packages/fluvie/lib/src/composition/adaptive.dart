import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/runtime/aspect_scope.dart';
import 'package:fluvie/src/core/aspect.dart';

/// One definition, many aspect ratios: picks the branch matching the active
/// [Aspect] and builds it.
///
/// `render(video, aspect:)` mounts an `AspectScope` over the composition, so an
/// `Adaptive` deep inside lays out for the aspect being rendered while timing and
/// animations resolve identically across aspects (only layout branches):
///
/// ```dart
/// Adaptive(
///   reels:     () => Column(children: [...]),   // vertical
///   square:    () => Row(children: [...]),       // side by side
///   landscape: () => Row(children: [...]),
/// );
/// ```
///
/// Each branch is a builder of plain content — put transforms and timing through
/// `.animate()`, not here. A branch you omit means "this composition does not
/// support that aspect": if a render asks for it, the build **throws an
/// [ArgumentError] naming the aspect** rather than rendering blank. The active
/// aspect is only known at build (via `AspectScope.of(context)`), so the check
/// happens there, not at construction.
final class Adaptive extends StatelessWidget {
  /// Creates an adaptive subtree; provide a builder for each aspect this
  /// composition supports. An omitted branch throws when that aspect renders.
  const Adaptive({this.reels, this.square, this.landscape, this.portrait45, super.key});

  /// The vertical 9:16 branch (`Aspect.reels`), or `null` when unsupported.
  final Widget Function()? reels;

  /// The square 1:1 branch (`Aspect.square`), or `null` when unsupported.
  final Widget Function()? square;

  /// The horizontal 16:9 branch (`Aspect.landscape`), or `null` when unsupported.
  final Widget Function()? landscape;

  /// The vertical 4:5 branch (`Aspect.portrait45`), or `null` when unsupported.
  final Widget Function()? portrait45;

  @override
  Widget build(BuildContext context) {
    final aspect = AspectScope.of(context);
    final builder = switch (aspect) {
      Aspect.reels => reels,
      Aspect.square => square,
      Aspect.landscape => landscape,
      Aspect.portrait45 => portrait45,
    };
    if (builder == null) {
      throw ArgumentError.value(
        aspect,
        'aspect',
        'Adaptive has no ${aspect.name} branch — this composition was rendered '
            'for an aspect it does not handle; add a ${aspect.name}: builder',
      );
    }
    return builder();
  }
}
