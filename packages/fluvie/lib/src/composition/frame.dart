import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/runtime/collectible_children.dart';

/// The deterministic shadow color and drop offset shared by [Frame.card] and
/// [Frame.polaroid]: 25% black, dropped 8 down. The blur radius
/// comes from the card's `elevation` (default 24).
const Color _shadowColor = Color(0x40000000);
const Offset _shadowOffset = Offset(0, 8);

/// The default card/polaroid blur radius: kept at 24 so the
/// existing layout goldens stay byte-identical. `Frame.card(elevation:)` sets
/// it directly; `Frame.polaroid` always uses this default.
const double _defaultElevation = 24;

/// The polaroid caption text style: a small neutral label centered under the
/// image, font-free in goldens because the harness substitutes Ahem.
const TextStyle _captionStyle = TextStyle(color: Color(0xFF333333), fontSize: 14);

/// The default frame child: nothing, so a `Frame` can be a style descriptor an
/// element fills with itself.
const Widget _emptyChild = SizedBox.shrink();

/// An optional decorative wrapper around visual content — the replacement for
/// the old `PhotoCard`/`PolaroidFrame` widgets.
///
/// Four styles, with micro-defaults pinned by the layout goldens (all trivially
/// changeable before 1.0):
///
/// - [Frame.none] — a pure passthrough;
/// - [Frame.rounded] — clips the child at `radius` (default 24);
/// - [Frame.card] — a white surface, radius 16, padding 12, one
///   deterministic drop shadow whose blur is `elevation` (default 24);
/// - [Frame.polaroid] — a square white border (12 each side, 48 below) with
///   the same shadow, optionally captioned under the image.
///
/// The media elements take a `Frame` directly (`Image.asset('me.png',
/// frame: Frame.polaroid(caption: 'Summer'))`); the element rewraps the frame
/// around itself with [withChild].
final class Frame extends StatelessWidget implements CollectibleChildren {
  /// No frame at all: builds [child] untouched.
  const Frame.none({this.child = _emptyChild, super.key})
    : _style = _FrameStyle.none,
      radius = 0,
      elevation = 0,
      caption = null;

  /// Clips [child] to a rounded rectangle of [radius] logical pixels.
  const Frame.rounded({this.child = _emptyChild, this.radius = 24, super.key})
    : _style = _FrameStyle.rounded,
      elevation = 0,
      caption = null;

  /// A white card surface behind [child]: [radius] corners (default 16),
  /// padding 12, and one deterministic shadow whose blur is [elevation]
  /// (default 24).
  const Frame.card({
    this.child = _emptyChild,
    this.radius = 16,
    this.elevation = _defaultElevation,
    super.key,
  }) : _style = _FrameStyle.card,
       caption = null;

  /// A polaroid-style white border around [child]: 12 on three sides, 48
  /// below, square corners, the same shadow, with an optional
  /// [caption] centered under the image.
  const Frame.polaroid({this.child = _emptyChild, this.caption, super.key})
    : _style = _FrameStyle.polaroid,
      radius = 0,
      elevation = _defaultElevation;

  /// The framed content. Defaults to nothing so a `Frame` can be passed as a
  /// pure style descriptor (`Image.asset(..., frame: Frame.polaroid())`) the
  /// element fills via [withChild].
  final Widget child;

  /// The corner radius the style clips or decorates with; `0` for the
  /// square styles ([Frame.none], [Frame.polaroid]).
  final double radius;

  /// The shadow blur radius for [Frame.card]/[Frame.polaroid] (default 24);
  /// `0` for the shadowless styles.
  final double elevation;

  /// The polaroid caption text, or `null` for none — only [Frame.polaroid]
  /// uses it.
  final String? caption;

  final _FrameStyle _style;

  /// The framed [child], so a `MediaCarrier` inside a `Frame` used as a wrapping
  /// widget is still pre-resolved. (As a `frame:` style descriptor a `Frame` is
  /// data on its element, not a tree node, so the collector never reaches here.)
  @override
  Iterable<Widget> get collectibleChildren => [child];

  /// Re-issues this frame's style around [newChild]: a `Frame`
  /// declares its style at construction, so an element wrapping itself rebuilds
  /// the same style with itself as the child, caption and metrics preserved.
  Frame withChild(Widget newChild) => switch (_style) {
    _FrameStyle.none => Frame.none(key: key, child: newChild),
    _FrameStyle.rounded => Frame.rounded(key: key, radius: radius, child: newChild),
    _FrameStyle.card => Frame.card(key: key, radius: radius, elevation: elevation, child: newChild),
    _FrameStyle.polaroid => Frame.polaroid(key: key, caption: caption, child: newChild),
  };

  @override
  Widget build(BuildContext context) => switch (_style) {
    _FrameStyle.none => child,
    _FrameStyle.rounded => ClipRRect(borderRadius: BorderRadius.circular(radius), child: child),
    _FrameStyle.card => _surface(
      borderRadius: BorderRadius.circular(radius),
      padding: const EdgeInsets.all(12),
    ),
    _FrameStyle.polaroid => _surface(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 48),
      caption: caption,
    ),
  };

  /// The shared card/polaroid shell: a white, shadowed surface whose
  /// [padding] insets [child] from the surface edge; an optional [caption] is
  /// drawn centered in the bottom border.
  ///
  /// The surface sizes to the padded [child] (the non-positioned Stack member),
  /// so the caption sits in the bottom band without changing the tight wrap the
  /// layout golden pins.
  Widget _surface({required EdgeInsets padding, BorderRadius? borderRadius, String? caption}) {
    final padded = Padding(padding: padding, child: child);
    final content = caption == null
        ? padded
        : Stack(
            alignment: Alignment.topLeft,
            children: [
              padded,
              Positioned(
                left: padding.left,
                right: padding.right,
                bottom: 0,
                height: padding.bottom,
                child: Center(
                  child: Text(
                    caption,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    style: _captionStyle,
                  ),
                ),
              ),
            ],
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: borderRadius,
        boxShadow: [BoxShadow(color: _shadowColor, blurRadius: elevation, offset: _shadowOffset)],
      ),
      child: content,
    );
  }
}

/// Which of the four styles a [Frame] renders.
enum _FrameStyle { none, rounded, card, polaroid }
