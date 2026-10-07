part of 'dart_spec_printer.dart';

/// The wave-2 preset calls (mirroring the spec's wave-2 dispatch): color data,
/// the pixel post-effects, the reactive presets, and the path-following
/// `along` form. Reactive `track` ids print as the shared anchor variables.
String _wave2Preset(String preset, Map<String, Object?> animation, _Anchors anchors) {
  final tail = _tail(animation, anchors, ambient: false);
  final ambientTail = _tail(animation, anchors, ambient: true);
  switch (preset) {
    case 'color':
      return 'Animation.color(${_args(['to: ${_color(animation['to'])}', ...tail])})';
    case 'gradientShift':
      final colors = [for (final color in animation['to']! as List) _color(color)].join(', ');
      return 'Animation.gradientShift(${_args(['to: [$colors]', ...tail])})';
    case 'scanlines':
      return 'Animation.scanlines(${_args(tail)})';
    case 'chromatic':
      final px = animation['px'] != null ? _num(animation['px']) : '0';
      return 'Animation.chromatic(${_args([px, ...tail])})';
    case 'bloom':
      final amount = animation['amount'] != null ? _num(animation['amount']) : '0';
      return 'Animation.bloom(${_args([amount, ...tail])})';
    case 'parallax':
      return 'Animation.parallax(${_args([_numArg('depth', animation['depth']), ...tail])})';
    case 'particles':
      return 'Animation.particles(${_args([_particles(_map(animation['spec'])), ...tail])})';
    case 'shader':
      return 'Animation.shader(${_args([
        _str(animation['asset']! as String),
        _uniformsArg(animation['uniforms']),
        ...tail,
      ])})';
    case 'scaleY':
      return 'Animation.scaleY(${_args([
        'on: ${_enumValue('AudioBand', animation['on']! as String)}',
        _numArg('gain', animation['gain']),
        _trackArg(animation['track'], anchors),
        ...ambientTail,
      ])})';
    case 'along':
      return 'Animation.along(${_args([
        'pathFromSvg(${_str(animation['path']! as String)})',
        if (animation['orient'] == false) 'orient: false',
        if (animation['phase'] != null) 'phase: ${_enumValue('AnimationPhase', animation['phase']! as String)}',
        ...tail,
      ])})';
  }
  throw FormatException('Unknown animation preset "$preset"');
}

/// A `Particles.<kind>(...)` spec; only the overridden fields print, so each
/// kind's own defaults stay elided.
String _particles(Map<String, Object?> spec) {
  final kind = spec['kind'];
  if (kind is! String || !const {'confetti', 'snow', 'sparkle'}.contains(kind)) {
    throw FormatException('Unknown particles kind "$kind"');
  }
  final palette = spec['palette'];
  return 'Particles.$kind(${_args([
    if (spec['count'] != null) 'count: ${_num(spec['count'])}',
    if (spec['seed'] != null) 'seed: ${_str(spec['seed']! as String)}',
    if (palette is List) 'palette: [${[for (final color in palette) _color(color)].join(', ')}]',
    _numArg('minSize', spec['minSize']),
    _numArg('maxSize', spec['maxSize']),
    _numArg('fallSpeed', spec['fallSpeed']),
    _numArg('drift', spec['drift']),
    _numArg('spinSpeed', spec['spinSpeed']),
  ])})';
}

/// The `uniforms: {...}` argument, elided when absent or empty; keys are
/// escaped string literals and values must be numbers.
String? _uniformsArg(Object? raw) {
  if (raw == null) return null;
  final map = _map(raw);
  if (map.isEmpty) return null;
  final entries = [for (final entry in map.entries) '${_str(entry.key)}: ${_num(entry.value)}'];
  return 'uniforms: {${entries.join(', ')}}';
}

/// The `track: <anchorVariable>` argument of a reactive preset, elided when
/// the animation reads the master mix.
String? _trackArg(Object? track, _Anchors anchors) =>
    track is String ? 'track: ${anchors.variableFor(track)}' : null;
