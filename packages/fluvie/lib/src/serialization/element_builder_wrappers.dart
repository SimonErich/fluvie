part of 'element_builder.dart';

// The wrapper elements each nest ONE full element in a `child` content prop,
// decoded recursively through ElementSpec — the child carries its own
// animate/transform/anchor like any scene child. All four build unwrapped:
// Callout and Spotlight stack only positioned children, so their stacks fill
// the bounded box they get (the scene, or a placed rect) and their painter
// coordinates are box coordinates, like LowerThird/TitleCard.

/// The one nested element a wrapper type carries, decoded recursively and
/// built through the document's shared [anchors] table (so a child's own
/// anchor or triggers keep document-wide identity).
Widget _childElement(Object? raw, AnchorTable anchors) {
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected an element object "child"', path: const ['child']);
  }
  return ElementSpec.fromJson(raw, anchors, path: const ['child']).build(anchors);
}

/// A `Snapshot` from its spec props: the child subtree is rasterized once
/// before the frame loop and painted as a still.
Widget _snapshot(Map<String, Object?> props, AnchorTable anchors) => Snapshot(
  fit: props['fit'] == null
      ? BoxFit.contain
      : decodeEnum(BoxFit.values, props['fit'], 'fit', path: const ['fit']),
  child: _childElement(props['child'], anchors),
);

/// A `DeviceFrame` from its spec props: `variant` picks the phone, browser, or
/// tablet chrome. A `notch` belongs to a phone and a `url` to a browser; on any
/// other variant the widget could only drop them silently, so the spec rejects
/// them loudly (the Chart data-shape precedent).
Widget _deviceFrame(Map<String, Object?> props, AnchorTable anchors) {
  final variant = props['variant'];
  if (variant != 'phone' && props['notch'] != null) {
    throw FluvieSpecError('Only a phone DeviceFrame takes "notch"', path: const ['notch']);
  }
  if (variant != 'browser' && props['url'] != null) {
    throw FluvieSpecError('Only a browser DeviceFrame takes "url"', path: const ['url']);
  }
  final url = props['url'];
  if (url != null && url is! String) {
    throw FluvieSpecError('Expected a string "url"', path: const ['url']);
  }
  return switch (variant) {
    'phone' => DeviceFrame.phone(
      notch: _boolOr(props['notch'], true, 'notch'),
      child: _childElement(props['child'], anchors),
    ),
    'browser' => DeviceFrame.browser(
      url: url as String?,
      child: _childElement(props['child'], anchors),
    ),
    'tablet' => DeviceFrame.tablet(child: _childElement(props['child'], anchors)),
    _ => throw FluvieSpecError(
      'Unknown device frame variant "$variant"; expected phone, browser, or tablet',
      path: const ['variant'],
    ),
  };
}

/// A `Callout` from its spec props: a label pill pointing an arrow at `target`,
/// annotating the child; `labelAt` mirrors the widget's (16, 16) default.
Widget _callout(Map<String, Object?> props, AnchorTable anchors) => Callout(
  label: _string(props['label'], 'label'),
  target: _offset(props['target'], 'target'),
  labelAt: props['labelAt'] == null
      ? const Offset(16, 16)
      : decodeOffset(props['labelAt'], path: const ['labelAt']),
  color: _colorOrNull(props['color']),
  child: _childElement(props['child'], anchors),
);

/// A `Spotlight` from its spec props: dims everything but `region` over the
/// child; the color mirrors the widget's translucent-black default.
Widget _spotlight(Map<String, Object?> props, AnchorTable anchors) => Spotlight.on(
  region: _rect(props['region'], 'region'),
  reveal: _revealOrNull(props['reveal']),
  color: props['color'] == null
      ? const Color(0xB3000000)
      : decodeColor(props['color'], path: const ['color']),
  child: _childElement(props['child'], anchors),
);
