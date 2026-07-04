import 'package:flutter/widgets.dart'
    show
        BorderRadius,
        BoxDecoration,
        BuildContext,
        Color,
        Column,
        CrossAxisAlignment,
        DecoratedBox,
        EdgeInsets,
        MainAxisSize,
        Matrix4,
        Padding,
        Positioned,
        Radius,
        Stack,
        StatelessWidget,
        Text,
        TextStyle,
        Transform,
        Widget;
import 'package:fluvie/src/composition/runtime/collectible_children.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/reveal/reveal_progress.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// How far the lower-third bar starts off the left edge before sliding in.
const double _slideDistance = 64;

/// A lower-third name/title bar that slides in from the edge — the broadcast
/// caption over a clip.
///
/// `LowerThird` may wrap a background [child], so it implements
/// `CollectibleChildren` — a `MediaCarrier` nested in the child is gathered by
/// the collect pass before frame 0. With no child it overlays nothing of its
/// own. Over its [reveal] window the bar
/// slides in horizontally from the left and settles, so it reads as arriving;
/// with no [reveal] it sits in place at every frame.
///
/// ```dart
/// LowerThird(name: 'Ada Lovelace', title: 'Mathematician', reveal: 12.frames);
/// ```
///
/// The bar background [color] defaults to a translucent dark band. Transforms
/// and effects ride `.animate()` on top of the intrinsic slide. [shared] wraps
/// the result in a `SharedElement` for a hero morph across a scene boundary.
///
/// Two durations can meet here: [reveal] times the intrinsic slide-in,
/// while transforms and opacity ride `.animate()` with their own timing.
final class LowerThird extends StatelessWidget implements CollectibleChildren {
  /// A lower third showing [name] and an optional [title], over an optional
  /// [child], sliding in over [reveal].
  const LowerThird({
    required this.name,
    this.title,
    this.child,
    this.reveal,
    this.color = const Color(0xCC101418),
    this.shared,
    super.key,
  });

  /// The primary line (a person or place name).
  final String name;

  /// The secondary line under the name, or `null` for a single line.
  final String? title;

  /// The optional background the bar overlays (rendered behind it).
  final Widget? child;

  /// The slide-in window resolved against the element scope, or `null` to sit in
  /// place at every frame.
  final Time? reveal;

  /// The bar background color.
  final Color color;

  /// An optional hero anchor: when non-null the bar morphs across the boundary
  /// it shares with the same anchor in the adjacent scene. `null` mounts no
  /// `SharedElement`.
  final Anchor? shared;

  @override
  Iterable<Widget> get collectibleChildren => [?child];

  @override
  Widget build(BuildContext context) {
    final dx = (1 - _progress(context)) * -_slideDistance;
    final bar = Transform(
      transform: Matrix4.translationValues(dx, 0, 0),
      child: _bar(),
    );
    final positioned = Positioned(left: 0, right: 0, bottom: 48, child: bar);
    final stacked = Stack(
      children: [
        if (child != null) Positioned.fill(child: child!),
        positioned,
      ],
    );
    return wrapShared(shared, stacked);
  }

  /// The padded name (and optional title) band.
  Widget _bar() => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 22)),
          if (title != null)
            Text(title!, style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14)),
        ],
      ),
    ),
  );

  /// The slide progress at this frame: `1` when there is no [reveal], else the
  /// shared reveal math resolved against the element scope.
  double _progress(BuildContext context) {
    final window = reveal;
    if (window == null) return 1;
    final frame = FrameProvider.of(context).frame;
    return revealProgress(frame, TimeScopeProvider.of(context), window);
  }
}
