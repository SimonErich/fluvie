import 'package:flutter/widgets.dart'
    show BuildContext, Color, CustomPaint, Offset, StatelessWidget, Widget;
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/annotations/render/connector_painter.dart';
import 'package:fluvie/src/elements/reveal/reveal_progress.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/theme/build_context_tokens.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// The default stroke width a [Connector] draws at when none is given.
const double _defaultStrokeWidth = 2;

/// A line linking two explicit points — the explicit-position form;
/// anchor-geometry resolution is not yet supported.
///
/// A `Connector` is a leaf painter — it draws geometry and wraps no child, so it
/// is not a `CollectibleChildren`. It joins [from] to [to] with a straight line,
/// or with a right-angle [elbow] that bends through a corner (horizontal first,
/// then vertical). Over its [drawIn] reveal it draws on from [from] toward [to];
/// with no [drawIn] it renders complete at every frame.
///
/// ```dart
/// Connector(from: const Offset(60, 60), to: const Offset(220, 160), elbow: true)
///     .animate([Animation.fadeIn()]);
/// ```
///
/// The [color] defaults to the first `context.fluvie` palette color so a
/// `FluvieTokensScope` rebrands every annotation at once; pass [color] to
/// override. Transforms and effects ride `.animate()` only. [shared] wraps the
/// result in a `SharedElement` for a hero morph across a scene boundary.
final class Connector extends StatelessWidget {
  /// A connector from [from] to [to], straight unless [elbow] is set.
  const Connector({
    required this.from,
    required this.to,
    this.elbow = false,
    this.color,
    this.strokeWidth = _defaultStrokeWidth,
    this.drawIn,
    this.shared,
    super.key,
  });

  /// The first linked point.
  final Offset from;

  /// The second linked point.
  final Offset to;

  /// Whether the connector bends through a right-angle corner (horizontal then
  /// vertical) instead of running straight.
  final bool elbow;

  /// The stroke color, or `null` to take the first `context.fluvie` palette
  /// color.
  final Color? color;

  /// The stroke width in logical pixels.
  final double strokeWidth;

  /// The draw-on reveal window resolved against the element scope, or `null` to
  /// render fully at every frame.
  final Time? drawIn;

  /// An optional hero anchor: when non-null the connector morphs across the
  /// boundary it shares with the same anchor in the adjacent scene. `null`
  /// mounts no `SharedElement`.
  final Anchor? shared;

  @override
  Widget build(BuildContext context) {
    final painter = ConnectorPainter(
      from: from,
      to: to,
      corner: elbow ? Offset(to.dx, from.dy) : null,
      color: color ?? context.fluvie.palette.colorAt(0),
      progress: _progress(context),
      strokeWidth: strokeWidth,
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
