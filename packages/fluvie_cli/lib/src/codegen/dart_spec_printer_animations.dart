part of 'dart_spec_printer.dart';

/// One `.animate([...])` entry: a named preset with its arguments, or a raw
/// `from`/`to`/`fromTo` keyframe animation, in both cases carrying the timing
/// tail (mirroring `buildAnimation`).
String _animation(Map<String, Object?> animation, _Anchors anchors) {
  final preset = animation['preset'];
  if (preset is String) return _preset(preset, animation, anchors);
  final tail = _tail(animation, anchors, ambient: false);
  final hasFrom = animation.containsKey('from');
  final hasTo = animation.containsKey('to');
  if (hasFrom && hasTo) {
    return 'Animation.fromTo(${_args([
      _keyframe(_map(animation['from'])),
      _keyframe(_map(animation['to'])),
      ...tail,
    ])})';
  }
  if (hasFrom) {
    return 'Animation.from(${_args([_keyframe(_map(animation['from'])), ...tail])})';
  }
  return 'Animation.to(${_args([_keyframe(_map(animation['to'])), ...tail])})';
}

String _preset(String preset, Map<String, Object?> animation, _Anchors anchors) {
  final tail = _tail(animation, anchors, ambient: false);
  final ambientTail = _tail(animation, anchors, ambient: true);
  switch (preset) {
    case 'fadeIn':
    case 'fadeOut':
      return 'Animation.$preset(${_args(tail)})';
    case 'slideIn':
    case 'slideFade':
      return 'Animation.$preset(${_args([_edgeArg('from', animation['from']), ...tail])})';
    case 'slideOut':
      return 'Animation.slideOut(${_args([_edgeArg('to', animation['to']), ...tail])})';
    case 'pop':
      return 'Animation.pop(${_args([_numArg('overshoot', animation['overshoot']), ...tail])})';
    case 'scaleIn':
      return 'Animation.scaleIn(${_args([_numArg('from', animation['from']), ...tail])})';
    case 'blurIn':
    case 'blurOut':
      return 'Animation.$preset(${_args([_numArg('sigma', animation['sigma']), ...tail])})';
    case 'grain':
    case 'vignette':
      final amount = animation['amount'] != null ? _num(animation['amount']) : '0';
      return 'Animation.$preset(${_args([amount, ...tail])})';
    case 'spin':
      final per = animation['per'];
      return 'Animation.spin(${_args([
        if (per != null) 'per: ${_time(per as String)}',
        ...ambientTail,
      ])})';
    case 'drift':
      return 'Animation.drift(${_args([
        _edgeArg('to', animation['to']),
        _numArg('distance', animation['distance']),
        ...ambientTail,
      ])})';
    case 'kenBurns':
      return 'Animation.kenBurns(${_args([
        _numArg('zoom', animation['zoom']),
        _edgeArg('pan', animation['pan']),
        ...ambientTail,
      ])})';
  }
  throw FormatException('Unknown animation preset "$preset"');
}

String? _edgeArg(String name, Object? value) =>
    value == null ? null : '$name: ${_enumValue('Edge', value as String)}';

String? _numArg(String name, Object? value) => value == null ? null : '$name: ${_num(value)}';

/// The shared timing tail. [ambient] presets (spin/drift/kenBurns) read no
/// duration/ease/spring, so those are dropped to match their signatures.
List<String?> _tail(Map<String, Object?> animation, _Anchors anchors, {required bool ambient}) => [
  if (!ambient && animation['duration'] != null)
    'duration: ${_time(animation['duration']! as String)}',
  if (!ambient && animation['ease'] != null) 'ease: ${_ease(animation['ease']! as String)}',
  if (!ambient && animation['spring'] != null) 'spring: ${_spring(animation['spring'])}',
  if (animation['delay'] != null) 'delay: ${_time(animation['delay']! as String)}',
  if (animation['at'] != null) 'at: ${_trigger(animation['at'], anchors)}',
  if (animation['stagger'] != null) 'stagger: ${_stagger(_map(animation['stagger']))}',
  if (animation['repeat'] != null) 'repeat: ${_repeat(_map(animation['repeat']))}',
  if (animation['label'] != null) 'label: ${_str(animation['label']! as String)}',
];

/// A `Keyframe(...)` over only its overridden fields, in canonical order.
String _keyframe(Map<String, Object?> keyframe) {
  const numeric = [
    'opacity',
    'x',
    'y',
    'scale',
    'scaleX',
    'scaleY',
    'rotation',
    'skewX',
    'skewY',
    'blur',
  ];
  return 'Keyframe(${_args([
    for (final field in numeric)
      if (keyframe[field] != null) '$field: ${_num(keyframe[field])}',
    if (keyframe['color'] != null) 'color: ${_color(keyframe['color'])}',
    if (keyframe['origin'] != null) 'origin: ${_alignment(keyframe['origin'])}',
  ])})';
}

/// A `Trigger` expression; anchor references resolve to the shared variables.
String _trigger(Object? raw, _Anchors anchors) {
  if (raw is String) {
    return switch (raw) {
      'auto' => 'Trigger.auto',
      'sceneStart' => 'Trigger.sceneStart',
      'sceneEnd' => 'Trigger.sceneEnd',
      'previous' => 'Trigger.previous',
      _ => throw FormatException('Unknown trigger "$raw"'),
    };
  }
  final map = _map(raw);
  switch (map['kind']) {
    case 'at':
      return 'Trigger.at(${_time(map['time']! as String)})';
    case 'beat':
      return 'Trigger.beat(${_args([
        if (map['every'] != null) 'every: ${_num(map['every'])}',
        if (map['track'] != null) 'track: ${anchors.variableFor(map['track']! as String)}',
      ])})';
    case 'whenEnds':
      return 'Trigger.whenEnds(${anchors.variableFor(map['anchor']! as String)})';
    case 'whenStarts':
      return 'Trigger.whenStarts(${anchors.variableFor(map['anchor']! as String)})';
  }
  throw FormatException('Unknown trigger kind "${map['kind']}"');
}
