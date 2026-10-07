import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/placement.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/animation_spec.dart';
import 'package:fluvie/src/serialization/clip_speed_codec.dart';
import 'package:fluvie/src/serialization/codecs/placement_codec.dart';
import 'package:fluvie/src/serialization/codecs/time_codec.dart';
import 'package:fluvie/src/serialization/effect_spec.dart';
import 'package:fluvie/src/serialization/element_builder.dart';
import 'package:fluvie/src/serialization/element_catalog.dart';

export 'package:fluvie/src/serialization/element_catalog.dart';

part 'element_spec_parser.dart';

/// The data form of one scene child: a `type`, its content `props`, an
/// optional stable `id`, an optional `transform` placement, an optional
/// `anchor` id, a `visible` flag, an optional `show` alive-window, and the
/// `animate` list applied through `.animate(...)`.
///
/// [buildElement] turns it into a real widget.
final class ElementSpec {
  /// Creates an element spec of [type] with [props], an optional stable
  /// [id], an optional [placement], an optional [anchor] id, a [visible]
  /// flag, optional [showFrom]/[showTo] window bounds, and an [animate]
  /// list.
  ElementSpec({
    required this.type,
    this.props = const {},
    this.id,
    this.placement,
    this.anchor,
    this.shared,
    this.visible = true,
    this.showFrom,
    this.showTo,
    this.animate = const [],
    this.lane,
    this.effects = const [],
  });

  /// Reads an element spec from [json], resolving animation anchors through
  /// [anchors].
  ///
  /// Throws a [FluvieSpecError] (located at [path]) for a missing/unknown
  /// `type`, a malformed `animate` list, or a malformed or empty `show`
  /// window (an empty `show` object carries no bound and is invalid).
  factory ElementSpec.fromJson(
    Map<String, Object?> json,
    AnchorTable anchors, {
    List<String> path = const [],
  }) => _parseElement(json, anchors, path);

  /// The keys every element reads regardless of its type; everything else is
  /// a content property owned by the type.
  static const Set<String> reservedElementKeys = {
    'type',
    'id',
    'transform',
    'anchor',
    'shared',
    'visible',
    'show',
    'animate',
    'lane',
    'effects',
  };

  /// The element type (`Text`, `Box`, `Image`, `Counter`).
  final String type;

  /// A stable identity for tools (selection, timelines, shared elements), or
  /// null when the document does not carry one. Fluvie preserves it verbatim
  /// and never mints one — identity policy belongs to the editing tool.
  final String? id;

  /// Where the element sits on the canvas, or null for the scene's stack
  /// placement (centered).
  final Placement? placement;

  /// The element's content properties, stored verbatim.
  final Map<String, Object?> props;

  /// The effects wrapping this element, in declaration order.
  ///
  /// Ordered by class when it builds — transform-class innermost, pixel-class
  /// outermost, list order preserved within a class — exactly as the animation
  /// pipeline already sorts the two, so a stack reads the same however it was
  /// typed.
  final List<EffectSpec> effects;

  /// The timeline row this element is drawn on, or null for none.
  ///
  /// A row, not a layer: paint order stays the `children` list. The key is
  /// `lane` and never `track`, because `track` is already a content prop — the
  /// Bars beat grid anchors on it — and reserving that name would pull it out
  /// of [props] and silently kill every beat grid.
  final String? lane;

  /// The anchor id naming this element's timeline, or null for none.
  final String? anchor;

  /// The shared-element ("hero") id pairing this element with the element
  /// naming the same id in an adjacent scene, or null for none. Both ids
  /// resolve to the same `Anchor` instance through the document's
  /// [AnchorTable] — that identity is the pairing.
  final String? shared;

  /// Whether the element renders at all. A hidden element (`false`) builds
  /// nothing mounted while keeping its place in the document, and the flag
  /// counts into the render digest — hiding IS a render change. Defaults to
  /// true and is elided from the JSON form when true.
  final bool visible;

  /// When the element becomes alive (the `show.from` bound), or null for the
  /// scene start. Only the authored bounds re-serialize; the defaults live in
  /// [window].
  final Time? showFrom;

  /// When the element stops being alive (the `show.to` bound), or null for
  /// the scene end.
  final Time? showTo;

  /// The animations applied to this element through `.animate(...)`.
  final List<AnimationSpec> animate;

  /// The desugared alive-window of the `show` key — `show({from, to})` is
  /// `animate([], window: from.to(to))` — with an absent bound falling to
  /// its scene edge ([Time.zero] / `Time.relative(1)`), or null when the
  /// element carries no `show` at all.
  TimeRange? get window => showFrom == null && showTo == null
      ? null
      : (showFrom ?? Time.zero).to(showTo ?? const Time.relative(1));

  /// The JSON form: the `type`, the optional `id` and `transform`, [props],
  /// the optional `anchor` and `shared`, `visible` only when false, `show`
  /// with only the authored bounds, and `animate`.
  Map<String, Object?> toJson() => {
    'type': type,
    if (id != null) 'id': id,
    if (placement != null) 'transform': encodePlacement(placement!),
    ...props,
    if (anchor != null) 'anchor': anchor,
    if (shared != null) 'shared': shared,
    if (!visible) 'visible': false,
    if (showFrom != null || showTo != null)
      'show': {
        if (showFrom != null) 'from': encodeTime(showFrom!),
        if (showTo != null) 'to': encodeTime(showTo!),
      },
    if (animate.isNotEmpty) 'animate': [for (final spec in animate) spec.toJson()],
    if (lane != null) 'lane': lane,
    if (effects.isNotEmpty) 'effects': [for (final effect in effects) effect.toJson()],
  };

  /// Builds the real widget, resolving its anchor through [anchors].
  Widget build(AnchorTable anchors) => buildElement(this, anchors);
}
