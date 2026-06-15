import 'package:flutter/widgets.dart'
    show BuildContext, Color, CustomPaint, Offset, StatelessWidget, Widget;
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/annotations/render/arrow_painter.dart';
import 'package:fluvie/src/elements/reveal/reveal_progress.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/theme/build_context_tokens.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// The default shaft width an [Arrow] draws at when none is given.
const double _defaultStrokeWidth = 3;

/// The default head length an [Arrow] draws at when none is given.
const double _defaultHeadLength = 16;

/// An annotation arrow pointing at a target: a stroked shaft with a filled
/// triangular head.
///
/// An `Arrow` is a leaf painter — it draws geometry and wraps no child, so it is
/// not a `CollectibleChildren`. Over its [drawIn] reveal the shaft draws on from
/// [from] toward [to], and the head appears once the shaft has fully drawn, so
/// the arrow reads as arriving. With no [drawIn] it renders complete at every
/// frame.
///
/// ```dart
/// Arrow.to(from: const Offset(40, 200), to: const Offset(160, 90), drawIn: 12.frames)
///     .animate([Animation.fadeIn()]);
/// ```
///
/// The [color] defaults to the first `context.fluvie` palette color so a
/// `FluvieTokensScope` rebrands every annotation at once; pass [color] to
/// override. Transforms and effects ride `.animate()` only. [shared] wraps the
/// result in a `SharedElement` for a hero morph across a scene boundary.
final class Arrow extends StatelessWidget {
  /// An arrow whose head points at [to], with its shaft starting at [from].
  const Arrow.to({
    required this.from,
    required this.to,
    this.color,
    this.strokeWidth = _defaultStrokeWidth,
    this.headLength = _defaultHeadLength,
    this.drawIn,
    this.shared,
    super.key,
  });

  /// The tail of the arrow (the shaft origin).
  final Offset from;

  /// The tip of the arrow (where the head points).
  final Offset to;

  /// The arrow color, or `null` to take the first `context.fluvie` palette
  /// color.
  final Color? color;

  /// The shaft stroke width in logical pixels.
  final double strokeWidth;

  /// The length of the triangular head along the shaft, in logical pixels.
  final double headLength;

  /// The draw-on reveal window resolved against the element scope, or `null` to
  /// render fully at every frame.
  final Time? drawIn;

  /// An optional hero anchor: when non-null the arrow morphs across the boundary
  /// it shares with the same anchor in the adjacent scene. `null` mounts no
  /// `SharedElement`.
  final Anchor? shared;

  @override
  Widget build(BuildContext context) {
    final painter = ArrowPainter(
      from: from,
      to: to,
      color: color ?? context.fluvie.palette.colorAt(0),
      progress: _progress(context),
      strokeWidth: strokeWidth,
      headLength: headLength,
    );
    return wrapShared(shared, CustomPaint(painter: painter));
  }

  /// The draw-on progress at this frame: `1` when there is no [drawIn], else the
  /// shared reveal math resolved against the element scope.
  double _progress(BuildContext context) {
    final reveal = drawIn;
    if (reveal == null) return 1;
    final frame = FrameProvider.of(context).frame;
    return revealProgress(frame, TimeScopeProvider.of(context), reveal);
  }
}
