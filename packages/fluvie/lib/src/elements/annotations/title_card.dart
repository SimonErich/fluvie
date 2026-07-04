import 'package:flutter/widgets.dart'
    show
        Alignment,
        BuildContext,
        Center,
        Color,
        Column,
        EdgeInsets,
        FontWeight,
        MainAxisSize,
        Opacity,
        Padding,
        Positioned,
        SizedBox,
        Stack,
        StatelessWidget,
        Text,
        TextAlign,
        TextStyle,
        Widget;
import 'package:fluvie/src/composition/runtime/collectible_children.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/reveal/reveal_progress.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// A centered title (and optional subtitle) that reveals over its window — the
/// chapter card between scenes.
///
/// `TitleCard` may wrap a background [child], so it implements
/// `CollectibleChildren` — a `MediaCarrier` nested in the child is gathered by
/// the collect pass before frame 0 (the collect-pass guard). Over its
/// [reveal] window the title fades up from transparent; with no [reveal] it sits
/// fully opaque at every frame.
///
/// ```dart
/// TitleCard(title: 'Chapter One', subtitle: 'The beginning', reveal: 20.frames);
/// ```
///
/// The title [color] defaults to white. Transforms and effects ride
/// `.animate()` on top of the intrinsic reveal. [shared] wraps the result in a
/// `SharedElement` for a hero morph across a scene boundary.
///
/// Two durations can meet here: [reveal] times the intrinsic reveal,
/// while transforms and opacity ride `.animate()` with their own timing.
final class TitleCard extends StatelessWidget implements CollectibleChildren {
  /// A title card showing [title] and an optional [subtitle], over an optional
  /// [child], revealing over [reveal].
  const TitleCard({
    required this.title,
    this.subtitle,
    this.child,
    this.reveal,
    this.color = const Color(0xFFFFFFFF),
    this.shared,
    super.key,
  });

  /// The centered headline.
  final String title;

  /// The line under the title, or `null` for a single line.
  final String? subtitle;

  /// The optional background the card centers over (rendered behind it).
  final Widget? child;

  /// The fade-up reveal window resolved against the element scope, or `null` to
  /// sit fully opaque at every frame.
  final Time? reveal;

  /// The title color (the subtitle is a dimmed shade of it).
  final Color color;

  /// An optional hero anchor: when non-null the card morphs across the boundary
  /// it shares with the same anchor in the adjacent scene. `null` mounts no
  /// `SharedElement`.
  final Anchor? shared;

  @override
  Iterable<Widget> get collectibleChildren => [?child];

  @override
  Widget build(BuildContext context) {
    final content = Opacity(
      opacity: _progress(context),
      child: Center(child: _titleBlock()),
    );
    final stacked = Stack(
      alignment: Alignment.center,
      children: [
        if (child != null) Positioned.fill(child: child!),
        Positioned.fill(child: content),
      ],
    );
    return wrapShared(shared, stacked);
  }

  /// The centered title and optional subtitle column.
  Widget _titleBlock() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: 40, fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 20),
          ),
        ],
      ],
    ),
  );

  /// The reveal progress at this frame: `1` when there is no [reveal], else the
  /// shared reveal math resolved against the element scope.
  double _progress(BuildContext context) {
    final window = reveal;
    if (window == null) return 1;
    final frame = FrameProvider.of(context).frame;
    return revealProgress(frame, TimeScopeProvider.of(context), window);
  }
}
