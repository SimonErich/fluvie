part of 'dart_spec_printer.dart';

/// A `Background.<kind>(...)` expression (mirroring `buildBackground`).
String _background(Map<String, Object?> background) {
  switch (background['kind']) {
    case 'color':
      return 'Background.color(${_color(background['color'])})';
    case 'gradient':
      return 'Background.gradient(${_args([
        _colors(background['colors']),
        if (background['begin'] != null) 'begin: ${_alignment(background['begin'])}',
        if (background['end'] != null) 'end: ${_alignment(background['end'])}',
      ])})';
    case 'radial':
      return 'Background.radial(${_colors(background['colors'])})';
    case 'image':
      return 'Background.image(${_args([
        _str(background['source']! as String),
        if (background['fit'] != null) 'fit: ${_enumValue('BoxFit', background['fit']! as String)}',
      ])})';
    case 'video':
      return 'Background.video(${_str(background['source']! as String)})';
    case 'noise':
      return 'Background.noise(${_args([
        if (background['scale'] != null) 'scale: ${_num(background['scale'])}',
      ])})';
    case 'vhs':
      return 'Background.vhs()';
  }
  throw FormatException('Unknown background "${background['kind']}"');
}

String _colors(Object? raw) {
  final list = raw! as List;
  return '[${[for (final color in list) _color(color)].join(', ')}]';
}

/// A `Transition.<kind>(...)` expression. The duration is positional; overlap,
/// ease, and the per-kind field are emitted when the JSON carries them.
String _transition(Map<String, Object?> transition) {
  final kind = transition['kind'];
  if (kind == 'cut') return 'Transition.cut()';
  final duration = _time(transition['duration']! as String);
  final tail = <String?>[
    if (transition['overlap'] != null) 'overlap: ${transition['overlap']}',
    if (transition['ease'] != null) 'ease: ${_ease(transition['ease']! as String)}',
  ];
  switch (kind) {
    case 'crossFade':
      return 'Transition.crossFade(${_args([duration, ...tail])})';
    case 'wipe':
      return 'Transition.wipe(${_args([
        duration,
        _edgeArg('direction', transition['direction']),
        ...tail,
      ])})';
    case 'zoom':
      return 'Transition.zoom(${_args([
        duration,
        if (transition['into'] != null) 'into: ${_alignment(transition['into'])}',
        ...tail,
      ])})';
    case 'slide':
      return 'Transition.slide(${_args([duration, _edgeArg('from', transition['from']), ...tail])})';
  }
  throw FormatException('Unknown transition "$kind"');
}

/// An `Export.<mode>(...)` expression.
String _export(Map<String, Object?> export) {
  switch (export['mode']) {
    case 'mp4':
      return 'Export.mp4(${_args([
        if (export['quality'] != null) 'quality: ${_enumValue('Quality', export['quality']! as String)}',
      ])})';
    case 'gif':
      return 'Export.gif(${_args([if (export['fps'] != null) 'fps: ${_num(export['fps'])}'])})';
    case 'imageSequence':
      return 'Export.imageSequence(${_args([
        if (export['format'] != null) 'format: ${_enumValue('ImageFormat', export['format']! as String)}',
      ])})';
    case 'transparent':
      return 'Export.transparent()';
  }
  throw FormatException('Unknown export mode "${export['mode']}"');
}

/// A `Defaults(...)` expression over its set fields.
String _defaults(Map<String, Object?> defaults) =>
    'Defaults(${_args([
      if (defaults['duration'] != null) 'duration: ${_time(defaults['duration']! as String)}',
      if (defaults['ease'] != null) 'ease: ${_ease(defaults['ease']! as String)}',
      if (defaults['stagger'] != null) 'stagger: ${_stagger(_map(defaults['stagger']))}',
    ])})';

/// A `Spring` value: a preset name, or the four-parameter constructor.
String _spring(Object? raw) {
  if (raw is String) return 'Spring.$raw';
  final map = _map(raw);
  return 'Spring(${_args([
    'stiffness: ${_num(map['stiffness'])}',
    'damping: ${_num(map['damping'])}',
    'mass: ${_num(map['mass'])}',
    'initialVelocity: ${_num(map['initialVelocity'])}',
  ])})';
}

/// A `Stagger` value: `each`, `evenly`, or `from`.
String _stagger(Map<String, Object?> stagger) {
  if (stagger.containsKey('each')) return 'Stagger.each(${_time(stagger['each']! as String)})';
  if (stagger.containsKey('evenly')) {
    return 'Stagger.evenly(over: ${_time(stagger['evenly']! as String)})';
  }
  return 'Stagger.from(${_args([
    _enumValue('StaggerOrigin', stagger['from']! as String),
    if (stagger['gap'] != null) 'gap: ${_time(stagger['gap']! as String)}',
  ])})';
}

/// A `Repeat` value: `forever` or a counted `times`.
String _repeat(Map<String, Object?> repeat) {
  final yoyo = repeat['yoyo'] == true ? 'yoyo: true' : null;
  if (repeat['forever'] == true) return 'Repeat.forever(${_args([yoyo])})';
  return 'Repeat.times(${_args([
    _num(repeat['times']),
    yoyo,
    if (repeat['gap'] != null) 'gap: ${_time(repeat['gap']! as String)}',
  ])})';
}
