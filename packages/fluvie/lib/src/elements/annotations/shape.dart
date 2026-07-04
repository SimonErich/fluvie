import 'package:flutter/widgets.dart'
    show BuildContext, Color, CustomPaint, Key, Offset, Path, Rect, StatelessWidget, Widget;
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/annotations/render/shape_painter.dart';
import 'package:fluvie/src/elements/reveal/reveal_progress.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/theme/build_context_tokens.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// The default stroke width an annotation [Shape] draws at when none is given.
const double _defaultStrokeWidth = 3;

/// A stroked annotation primitive — a line, rectangle, circle, or path — drawn
/// over a chart, screenshot, or any frame.
///
/// A `Shape` is a leaf painter: it draws geometry and wraps no child, so it is
/// not a `CollectibleChildren`. Each variant draws on left-to-right over its
/// [reveal] reveal (the same `0 -> 1` reveal math charts use): the stroke grows
/// along its own length rather than fading. With no [reveal] it renders fully at
/// every frame.
///
/// ```dart
/// Shape.circle(center: const Offset(160, 90), radius: 40, reveal: 12.frames)
///     .animate([Animation.fadeIn()]);
/// ```
///
/// The stroke [color] defaults to the first `context.fluvie` palette color so a
/// `FluvieTokensScope` rebrands every annotation at once; pass [color] to
/// override. Transforms and effects ride `.animate()` only — the constructor
/// takes geometry and nothing else. [shared] wraps the result in a
/// `SharedElement` for a hero morph across a scene boundary.
///
/// Two durations can meet here: [reveal] times the intrinsic draw-on,
/// while transforms and opacity ride `.animate()` with their own timing.
final class Shape extends StatelessWidget {
  /// The base constructor every named factory delegates to; carries the resolved
  /// [kind] geometry and shared draw-on inputs.
  const Shape._({
    required this.kind,
    this.from,
    this.to,
    this.rect,
    this.center,
    this.radius,
    this.path,
    this.color,
    this.strokeWidth = _defaultStrokeWidth,
    this.reveal,
    this.shared,
    super.key,
  });

  // coverage:ignore-start const ctor artifacts shape_test pins Shape line and Shape rect geometry kind plus the painter inputs Const literals are not instrumented
  /// A straight line from [from] to [to].
  const Shape.line({
    required Offset from,
    required Offset to,
    Color? color,
    double strokeWidth = _defaultStrokeWidth,
    Time? reveal,
    Anchor? shared,
    Key? key,
  }) : this._(
         kind: ShapeKind.line,
         from: from,
         to: to,
         color: color,
         strokeWidth: strokeWidth,
         reveal: reveal,
         shared: shared,
         key: key,
       );

  /// A rectangle outlining [rect].
  const Shape.rect({
    required Rect rect,
    Color? color,
    double strokeWidth = _defaultStrokeWidth,
    Time? reveal,
    Anchor? shared,
    Key? key,
  }) : this._(
         kind: ShapeKind.rect,
         rect: rect,
         color: color,
         strokeWidth: strokeWidth,
         reveal: reveal,
         shared: shared,
         key: key,
       );
  // coverage:ignore-end

  /// A circle of [radius] around [center].
  const Shape.circle({
    required Offset center,
    required double radius,
    Color? color,
    double strokeWidth = _defaultStrokeWidth,
    Time? reveal,
    Anchor? shared,
    Key? key,
  }) : this._(
         kind: ShapeKind.circle,
         center: center,
         radius: radius,
         color: color,
         strokeWidth: strokeWidth,
         reveal: reveal,
         shared: shared,
         key: key,
       );

  /// An arbitrary stroked [path].
  const Shape.path({
    required Path path,
    Color? color,
    double strokeWidth = _defaultStrokeWidth,
    Time? reveal,
    Anchor? shared,
    Key? key,
  }) : this._(
         kind: ShapeKind.path,
         path: path,
         color: color,
         strokeWidth: strokeWidth,
         reveal: reveal,
         shared: shared,
         key: key,
       );

  /// Which primitive this draws.
  final ShapeKind kind;

  /// The start point of a [Shape.line].
  final Offset? from;

  /// The end point of a [Shape.line].
  final Offset? to;

  /// The bounds of a [Shape.rect].
  final Rect? rect;

  /// The center of a [Shape.circle].
  final Offset? center;

  /// The radius of a [Shape.circle].
  final double? radius;

  /// The outline of a [Shape.path].
  final Path? path;

  /// The stroke color, or `null` to take the first `context.fluvie` palette
  /// color.
  final Color? color;

  /// The stroke width in logical pixels.
  final double strokeWidth;

  /// The draw-on reveal window resolved against the element scope, or `null` to
  /// render fully at every frame.
  final Time? reveal;

  /// An optional hero anchor: when non-null the shape morphs across the
  /// boundary it shares with the same anchor in the adjacent scene. `null`
  /// mounts no `SharedElement`.
  final Anchor? shared;

  @override
  Widget build(BuildContext context) {
    final progress = _progress(context);
    final painter = ShapePainter(
      kind: kind,
      color: color ?? context.fluvie.palette.colorAt(0),
      progress: progress,
      strokeWidth: strokeWidth,
      from: from,
      to: to,
      rect: rect,
      center: center,
      radius: radius,
      path: path,
    );
    return wrapShared(shared, CustomPaint(painter: painter));
  }

  /// The draw-on progress at this frame: `1` when there is no [reveal], else the
  /// shared reveal math resolved against the element scope.
  double _progress(BuildContext context) {
    final window = reveal;
    if (window == null) return 1;
    final frame = FrameProvider.of(context).frame;
    return revealProgress(frame, TimeScopeProvider.of(context), window);
  }
}
