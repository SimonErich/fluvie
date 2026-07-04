import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/animation_spec.dart';
import 'package:fluvie/src/serialization/element_builder.dart';

/// The element types the spec can build.
const Set<String> knownElementTypes = {'Text', 'Box', 'Image', 'Counter'};

/// The content properties each element type reads, beyond the reserved keys
/// (`type`, `anchor`, `animate`). This is the single source of truth shared by
/// the parser's unknown-property check and `videoSpecSchema`; it must stay in
/// step with what `buildElement` actually reads in `element_builder.dart`.
const Map<String, Set<String>> knownElementProps = {
  'Text': {'text', 'style'},
  'Box': {'color', 'size'},
  'Image': {'source', 'fit'},
  'Counter': {'to', 'from', 'reveal', 'style'},
};

/// The data form of one scene child: a `type`, its content `props`, an optional
/// `anchor` id, and the `animate` list applied through `.animate(...)`.
///
/// [buildElement] turns it into a real widget.
class ElementSpec {
  /// Creates an element spec of [type] with [props], an optional [anchor] id,
  /// and an [animate] list.
  ElementSpec({
    required this.type,
    this.props = const {},
    this.anchor,
    this.animate = const [],
  });

  /// Reads an element spec from [json], resolving animation anchors through
  /// [anchors].
  ///
  /// Throws a [FluvieSpecError] (located at [path]) for a missing/unknown
  /// `type` or a malformed `animate` list.
  factory ElementSpec.fromJson(
    Map<String, Object?> json,
    AnchorTable anchors, {
    List<String> path = const [],
  }) {
    final type = json['type'];
    if (type is! String) {
      throw FluvieSpecError('An element needs a "type"', path: path);
    }
    if (!knownElementTypes.contains(type)) {
      throw FluvieSpecError('Unknown element "$type"', path: path);
    }
    final animate = <AnimationSpec>[];
    final animateRaw = json['animate'];
    if (animateRaw is List) {
      for (var i = 0; i < animateRaw.length; i++) {
        final entry = animateRaw[i];
        if (entry is! Map<String, Object?>) {
          throw FluvieSpecError('Expected an animation object', path: [...path, 'animate', '$i']);
        }
        animate.add(AnimationSpec.fromJson(entry, anchors, path: [...path, 'animate', '$i']));
      }
    } else if (animateRaw != null) {
      throw FluvieSpecError('Expected "animate" to be a list', path: [...path, 'animate']);
    }
    final anchorId = json['anchor'];
    final props = <String, Object?>{
      for (final entry in json.entries)
        if (!_reserved.contains(entry.key)) entry.key: entry.value,
    };
    return ElementSpec(
      type: type,
      props: props,
      anchor: anchorId is String ? anchorId : null,
      animate: animate,
    );
  }

  static const Set<String> _reserved = {'type', 'anchor', 'animate'};

  /// The element type (`Text`, `Box`, `Image`, `Counter`).
  final String type;

  /// The element's content properties, stored verbatim.
  final Map<String, Object?> props;

  /// The anchor id naming this element's timeline, or null for none.
  final String? anchor;

  /// The animations applied to this element through `.animate(...)`.
  final List<AnimationSpec> animate;

  /// The JSON form: the `type`, [props], the optional `anchor`, and `animate`.
  Map<String, Object?> toJson() => {
    'type': type,
    ...props,
    if (anchor != null) 'anchor': anchor,
    if (animate.isNotEmpty) 'animate': [for (final spec in animate) spec.toJson()],
  };

  /// Builds the real widget, resolving its anchor through [anchors].
  Widget build(AnchorTable anchors) => buildElement(this, anchors);
}
