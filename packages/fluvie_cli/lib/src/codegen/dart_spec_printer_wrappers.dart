part of 'dart_spec_printer.dart';

/// The element types whose `child` prop nests one full element, mirrored from
/// fluvie's `knownElementProps`; the anchor collector recurses through exactly
/// these so a child's anchors are declared without ever declaring one for a
/// stray `child` key on a non-wrapper type.
const Set<String> _childBearingTypes = {
  'Snapshot',
  'DeviceFrame',
  'Callout',
  'Spotlight',
  'LowerThird',
  'TitleCard',
};

/// The nested element a wrapper carries, printed as a full `child:` argument;
/// the child recurses through `_element`, so its own animate/transform/anchor
/// print exactly like a scene child's. A hidden child prints the shrink the
/// builder mounts (the wrapper still needs a widget in the slot).
String _childArg(Map<String, Object?> element, _Anchors anchors) {
  final child = _map(element['child']);
  if (child['visible'] == false) {
    return 'child: const SizedBox.shrink() /* ${_hiddenLabel(child)} */';
  }
  return 'child: ${_element(child, anchors)}';
}

/// A `Snapshot(...)` constructor, mirroring `_snapshot` in fluvie's builder.
String _snapshotElement(Map<String, Object?> element, _Anchors anchors) =>
    'Snapshot(${_args([
      if (element['fit'] != null) 'fit: ${_enumValue('BoxFit', element['fit']! as String)}',
      _childArg(element, anchors),
    ])})';

/// A `DeviceFrame.<variant>(...)` constructor. A `notch` belongs to a phone
/// and a `url` to a browser; anywhere else the printer rejects them exactly
/// like the spec builder, so the two layers agree.
String _deviceFrameElement(Map<String, Object?> element, _Anchors anchors) {
  final variant = element['variant'];
  if (variant != 'phone' && element['notch'] != null) {
    throw const FormatException('Only a phone DeviceFrame takes "notch"');
  }
  if (variant != 'browser' && element['url'] != null) {
    throw const FormatException('Only a browser DeviceFrame takes "url"');
  }
  return switch (variant) {
    'phone' =>
      'DeviceFrame.phone(${_args([
        if (element['notch'] == false) 'notch: false',
        _childArg(element, anchors),
      ])})',
    'browser' =>
      'DeviceFrame.browser(${_args([
        if (element['url'] != null) 'url: ${_str(element['url']! as String)}',
        _childArg(element, anchors),
      ])})',
    'tablet' => 'DeviceFrame.tablet(${_childArg(element, anchors)})',
    _ => throw FormatException('Unknown device frame variant "$variant"'),
  };
}

/// A `Callout(...)` constructor, eliding the widget's (16, 16) `labelAt`
/// default.
String _calloutElement(Map<String, Object?> element, _Anchors anchors) =>
    'Callout(${_args([
      'label: ${_str(element['label']! as String)}',
      'target: ${_point(element['target'])}',
      if (element['labelAt'] != null) 'labelAt: ${_point(element['labelAt'])}',
      if (element['color'] != null) 'color: ${_color(element['color'])}',
      _childArg(element, anchors),
    ])})';

/// A `Spotlight.on(...)` constructor, eliding the widget's translucent-black
/// dim default.
String _spotlightElement(Map<String, Object?> element, _Anchors anchors) =>
    'Spotlight.on(${_args([
      'region: ${_rectLiteral(element['region'])}',
      if (element['reveal'] != null) 'reveal: ${_time(element['reveal']! as String)}',
      if (element['color'] != null) 'color: ${_color(element['color'])}',
      _childArg(element, anchors),
    ])})';
