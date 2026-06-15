/// @docImport 'package:fluvie/src/elements/annotations/arrow.dart';
/// @docImport 'package:fluvie/src/elements/image.dart';
library;

import 'package:flutter/widgets.dart'
    show
        BorderRadius,
        BoxDecoration,
        BuildContext,
        Color,
        CustomPaint,
        DecoratedBox,
        EdgeInsets,
        Offset,
        Padding,
        Positioned,
        Radius,
        Stack,
        StatelessWidget,
        Text,
        TextStyle,
        Widget;
import 'package:fluvie/src/composition/runtime/collectible_children.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/elements/annotations/render/arrow_painter.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/theme/build_context_tokens.dart';

/// The default top-left corner a callout label sits at when none is given.
const Offset _defaultLabelAt = Offset(16, 16);

/// A label that points at a target with an arrow, annotating a [child].
///
/// `Callout` wraps a [child] (the content it annotates), so it implements
/// `CollectibleChildren` — a `MediaCarrier` nested in the child is gathered by
/// the collect pass before frame 0. It is an [Arrow] plus a label pill: the
/// label sits at [labelAt] and the arrow runs
/// from the label toward [target]. The arrow is a capture-safe `CustomPaint`
/// (no `saveLayer`).
///
/// ```dart
/// Callout(
///   label: 'Active users',
///   target: const Offset(420, 180),
///   child: Image.asset('dashboard.png'),
/// );
/// ```
///
/// The arrow and label accent [color] default to the first `context.fluvie`
/// palette color. Transforms and effects ride `.animate()` only. [shared] wraps
/// the result in a `SharedElement` for a hero morph across a scene boundary.
final class Callout extends StatelessWidget implements CollectibleChildren {
  /// Annotates [child] with a [label] pill pointing an arrow at [target].
  const Callout({
    required this.label,
    required this.target,
    required this.child,
    this.labelAt = _defaultLabelAt,
    this.color,
    this.shared,
    super.key,
  });

  /// The callout text shown in the label pill.
  final String label;

  /// The point the arrow points at, in the child's coordinate space.
  final Offset target;

  /// The content the callout annotates (rendered behind it).
  final Widget child;

  /// The top-left corner the label pill sits at.
  final Offset labelAt;

  /// The arrow and pill accent color, or `null` to take the first
  /// `context.fluvie` palette color.
  final Color? color;

  /// An optional hero anchor: when non-null the callout morphs across the
  /// boundary it shares with the same anchor in the adjacent scene. `null`
  /// mounts no `SharedElement`.
  final Anchor? shared;

  @override
  Iterable<Widget> get collectibleChildren => [child];

  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.fluvie.palette.colorAt(0);
    final stacked = Stack(
      children: [
        Positioned.fill(child: child),
        Positioned.fill(child: CustomPaint(painter: _arrowPainter(accent))),
        Positioned(left: labelAt.dx, top: labelAt.dy, child: _label(accent)),
      ],
    );
    return wrapShared(shared, stacked);
  }

  /// The arrow from the label pill toward [target], fully drawn (the callout
  /// reveal rides `.animate()`, not a per-element draw-on).
  ArrowPainter _arrowPainter(Color accent) => ArrowPainter(
    from: labelAt + const Offset(8, 28),
    to: target,
    color: accent,
    progress: 1,
    strokeWidth: 3,
    headLength: 14,
  );

  /// The label pill: padded white-on-accent text.
  Widget _label(Color accent) => DecoratedBox(
    decoration: BoxDecoration(
      color: accent,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(label, style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14)),
    ),
  );
}
