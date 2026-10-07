part of 'dart_spec_printer.dart';

/// One `.animate([...])` entry: a named preset with its arguments, the
/// multi-stop `keyframes` form, or a raw `from`/`to`/`fromTo` keyframe
/// animation, in every case carrying the timing tail (mirroring
/// `buildAnimation`).
String _animation(Map<String, Object?> animation, _Anchors anchors) {
  final preset = animation['preset'];
  if (preset is String) {
    final result = _preset(preset, animation, anchors);
    const ambient = {'float', 'pulse', 'scaleY', 'drift', 'spin', 'kenBurns'};
    return ambient.contains(preset) && animation['ease'] != null
        ? '$result.withEase(${_ease(animation['ease'])})'
        : result;
  }
  if (animation.containsKey('keyframes')) return _keyframesCall(animation, anchors);
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

/// An `Animation.keyframes(...)` call: the stops positionally, then
/// `easings`, the positions as `at:`, and `phase:` — with the tail's start
/// trigger printed as `trigger:`, because `at:` names the stop positions on
/// this constructor (mirroring the Dart signature).
String _keyframesCall(Map<String, Object?> animation, _Anchors anchors) {
  final stops = animation['keyframes']! as List;
  final easings = animation['easings'] as List?;
  final positions = animation['positions'] as List?;
  final phase = animation['phase'];
  return 'Animation.keyframes(${_args([
    '[${stops.map((stop) => _keyframe(_map(stop))).join(', ')}]',
    if (easings != null) 'easings: [${easings.map(_ease).join(', ')}]',
    if (positions != null) 'at: [${positions.map((time) => _time(time! as String)).join(', ')}]',
    if (phase != null) 'phase: ${_enumValue('AnimationPhase', phase as String)}',
    ..._tail(animation, anchors, ambient: false, atName: 'trigger'),
  ])})';
}

String _preset(String preset, Map<String, Object?> animation, _Anchors anchors) {
  final tail = _tail(animation, anchors, ambient: false);
  final ambientTail = _tail(animation, anchors, ambient: true);
  switch (preset) {
    case 'fadeIn':
    case 'fadeOut':
      return 'Animation.$preset(${_args(tail)})';
    case 'slideIn':
    case 'slideFadeIn':
      return 'Animation.$preset(${_args([_edgeArg('from', animation['from']), ...tail])})';
    case 'slideOut':
    case 'slideFadeOut':
      return 'Animation.$preset(${_args([_edgeArg('to', animation['to']), ...tail])})';
    case 'pop':
      return 'Animation.pop(${_args([_numArg('overshoot', animation['overshoot']), ...tail])})';
    case 'scaleIn':
      return 'Animation.scaleIn(${_args([_numArg('from', animation['from']), ...tail])})';
    case 'scaleOut':
      return 'Animation.scaleOut(${_args([_numArg('to', animation['to']), ...tail])})';
    case 'blurIn':
    case 'blurOut':
      return 'Animation.$preset(${_args([_numArg('sigma', animation['sigma']), ...tail])})';
    case 'grain':
    case 'vignette':
      final amount = animation['amount'] != null ? _num(animation['amount']) : '0';
      return 'Animation.$preset(${_args([amount, ...tail])})';
    case 'spin':
      final period = animation['period'];
      return 'Animation.spin(${_args([
        if (period != null) 'period: ${_time(period as String)}',
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
    case 'maskWipeIn':
    case 'maskWipeOut':
      return 'Animation.$preset(${_args([
        if (animation['shape'] != null) 'shape: ${_enumValue('WipeShape', animation['shape']! as String)}',
        if (animation['origin'] != null) 'origin: ${_alignment(animation['origin'])}',
        ...tail,
      ])})';
    case 'glitchIn':
      return 'Animation.glitchIn(${_args([_edgeArg('from', animation['from']), ...tail])})';
    case 'glitchOut':
      return 'Animation.glitchOut(${_args([_edgeArg('to', animation['to']), ...tail])})';
    case 'float':
      return 'Animation.float(${_args([
        _numArg('amplitude', animation['amplitude']),
        if (animation['period'] != null) 'period: ${_time(animation['period']! as String)}',
        if (animation['seed'] != null) 'seed: ${_str(animation['seed']! as String)}',
        ...ambientTail,
      ])})';
    case 'pulse':
      return 'Animation.pulse(${_args([
        if (animation['on'] != null) 'on: ${_enumValue('AudioBand', animation['on']! as String)}',
        _numArg('gain', animation['gain']),
        _trackArg(animation['track'], anchors),
        _numArg('min', animation['min']),
        _numArg('max', animation['max']),
        if (animation['period'] != null) 'period: ${_time(animation['period']! as String)}',
        ...ambientTail,
      ])})';
  }
  return _wave2Preset(preset, animation, anchors);
}

String? _edgeArg(String name, Object? value) =>
    value == null ? null : '$name: ${_enumValue('Edge', value as String)}';

String? _numArg(String name, Object? value) => value == null ? null : '$name: ${_num(value)}';

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
