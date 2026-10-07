import 'dart:ui' show Color, Offset, Rect;

import 'package:flutter/widgets.dart'
    show
        Align,
        BoxConstraints,
        BoxDecoration,
        BoxFit,
        ConstrainedBox,
        DecoratedBox,
        EdgeInsets,
        Padding,
        Size,
        SizedBox,
        Stack,
        Text,
        TextAlign,
        TextDecoration,
        TextSpan,
        TextStyle,
        TextWidthBasis,
        Widget;
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/box.dart';
import 'package:fluvie/src/composition/photo_frame.dart';
import 'package:fluvie/src/composition/runtime/spec_element_id.dart';
import 'package:fluvie/src/core/audio_band.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/media/clip_audio.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/snapshot/snapshot_viewport.dart';
import 'package:fluvie/src/core/svg_path.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/elements/annotations/arrow.dart';
import 'package:fluvie/src/elements/annotations/callout.dart';
import 'package:fluvie/src/elements/annotations/connector.dart';
import 'package:fluvie/src/elements/annotations/lower_third.dart';
import 'package:fluvie/src/elements/annotations/shape.dart';
import 'package:fluvie/src/elements/annotations/spotlight.dart';
import 'package:fluvie/src/elements/annotations/title_card.dart';
import 'package:fluvie/src/elements/bars/bars.dart';
import 'package:fluvie/src/elements/chart/chart.dart';
import 'package:fluvie/src/elements/chart/data/chart_point.dart';
import 'package:fluvie/src/elements/chart/data/chart_series.dart';
import 'package:fluvie/src/elements/clip.dart';
import 'package:fluvie/src/elements/code/code.dart';
import 'package:fluvie/src/elements/code/code_reveal.dart';
import 'package:fluvie/src/elements/code/theme/code_theme.dart';
import 'package:fluvie/src/elements/counter.dart';
import 'package:fluvie/src/elements/image.dart';
import 'package:fluvie/src/elements/markdown/markdown.dart';
import 'package:fluvie/src/elements/mermaid/mermaid.dart';
import 'package:fluvie/src/elements/mermaid/mermaid_reveal.dart';
import 'package:fluvie/src/elements/mermaid/mermaid_theme.dart';
import 'package:fluvie/src/elements/placed.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/elements/snapshot/device_frame.dart';
import 'package:fluvie/src/elements/snapshot/snapshot.dart';
import 'package:fluvie/src/elements/split_text.dart';
import 'package:fluvie/src/elements/terminal/terminal.dart';
import 'package:fluvie/src/elements/terminal/terminal_chrome.dart';
import 'package:fluvie/src/elements/terminal/terminal_line.dart';
import 'package:fluvie/src/elements/typewriter.dart';
import 'package:fluvie/src/elements/webview/html.dart';
import 'package:fluvie/src/elements/webview/webview.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/animation_builder.dart';
import 'package:fluvie/src/serialization/audio_automation.dart';
import 'package:fluvie/src/serialization/bundle_media.dart';
import 'package:fluvie/src/serialization/clip_speed_codec.dart';
import 'package:fluvie/src/serialization/codecs/box_decoration_codec.dart';
import 'package:fluvie/src/serialization/codecs/color_codec.dart';
import 'package:fluvie/src/serialization/codecs/curve_codec.dart';
import 'package:fluvie/src/serialization/codecs/enum_codec.dart';
import 'package:fluvie/src/serialization/codecs/geometry_codec.dart';
import 'package:fluvie/src/serialization/codecs/motion_codec.dart';
import 'package:fluvie/src/serialization/codecs/text_style_codec.dart';
import 'package:fluvie/src/serialization/codecs/time_codec.dart';
import 'package:fluvie/src/serialization/effect_builder.dart';
import 'package:fluvie/src/serialization/element_spec.dart';
import 'package:fluvie/src/serialization/media_file_base.dart';

part 'element_builder_annotations.dart';
part 'element_builder_charts.dart';
part 'element_builder_group.dart';
part 'element_builder_dispatch.dart';
part 'element_builder_media.dart';
part 'element_builder_primitives.dart';
part 'element_builder_terminal_code.dart';
part 'element_builder_text.dart';
part 'element_builder_web.dart';
part 'element_builder_wrappers.dart';

/// Builds a real widget from an [ElementSpec], wrapping it in a
/// `SharedElement` when it carries a `shared` id (before `.animate(...)`,
/// mirroring how widgets with a `shared:` parameter wrap internally), in
/// `.animate(...)` when it has animations, an anchor, or a `show` window
/// (the window rides the one call as its `window:` argument — one
/// `MotionTarget`, so the element's animations resolve inside it), in
/// [SpecElementId] when it carries an `id` (directly around the animated
/// form, so timeline introspection joins the element's resolved spans to its
/// document id), and in [Placed] when it carries a `transform` — so
/// animations play relative to the element's placed home. Two elements
/// naming the same `shared` id resolve to the same `Anchor` instance through
/// [anchors]; that identity is the hero pairing.
///
/// A `visible: false` element builds nothing mounted — a zero-size
/// `SizedBox.shrink` keeps its slot so sibling indices hold steady (and it
/// never introspects: nothing of it mounts). Hidden wins over `show`: a
/// window on a hidden element never mounts either.
Widget buildElement(ElementSpec spec, AnchorTable anchors, {Widget? baseOverride}) {
  if (!spec.visible) return const SizedBox.shrink();
  final sharedId = spec.shared;
  final base = sharedId == null
      ? baseOverride ?? _base(spec, anchors)
      : wrapShared(anchors.resolve(sharedId), baseOverride ?? _base(spec, anchors));
  // Inside the .animate(...) wrapper and outside the element's own widget:
  // a hand author's stack lands in exactly this slot, because `shared:` is a
  // constructor argument of the element itself.
  final effected = buildEffectStack(spec.effects, base);
  final animations = <Animation>[
    for (final animation in spec.animate) buildAnimation(animation, anchors),
  ];
  final anchorId = spec.anchor;
  final anchor = anchorId == null ? null : anchors.resolve(anchorId);
  final window = spec.window;
  final animated = animations.isEmpty && anchor == null && window == null
      ? effected
      : effected.animate(animations, anchor: anchor, window: window);
  final id = spec.id;
  final identified = id == null
      ? animated
      : SpecElementId(id: id, lane: spec.lane, child: animated);
  final placement = spec.placement;
  if (placement == null) return identified;
  return Placed(placement: placement, id: id, child: identified);
}
