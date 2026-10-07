part of 'animation_builder.dart';

// The shared preset-argument decoders: each turns one raw spec value into the
// typed argument a preset constructor takes, throwing a located
// FluvieSpecError instead of silently dropping a malformed value.

List<Color> _colorList(Object? raw) {
  if (raw is! List) {
    throw FluvieSpecError('Expected a list of colors "to"', path: const ['to']);
  }
  return [
    for (final color in raw) decodeColor(color, path: const ['to']),
  ];
}

/// The untrusted-render boundary for `shader`: the asset must be a plain
/// relative asset path — no absolute paths, no `..` segments, no URL schemes —
/// so a spec can only name shaders bundled with the host app.
String _shaderAsset(Object? raw) {
  if (raw is! String || raw.isEmpty) {
    throw FluvieSpecError('A shader needs an "asset" path string', path: const ['asset']);
  }
  final absolute = raw.startsWith('/') || raw.startsWith(r'\');
  final escapes = raw.split(RegExp(r'[/\\]')).contains('..');
  if (absolute || escapes || raw.contains(':')) {
    throw FluvieSpecError(
      'A shader "asset" must be a plain relative asset path (no absolute '
      'paths, no "..", no URL schemes); got "$raw"',
      path: const ['asset'],
    );
  }
  return raw;
}

Map<String, Object> _uniforms(Object? raw) {
  if (raw == null) return const {};
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a "uniforms" object of numbers', path: const ['uniforms']);
  }
  final uniforms = <String, Object>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is! num) {
      throw FluvieSpecError(
        'Shader uniform "${entry.key}" must be a number (one float slot)',
        path: ['uniforms', entry.key],
      );
    }
    uniforms[entry.key] = value;
  }
  return uniforms;
}

Anchor? _trackAnchor(Object? raw, AnchorTable anchors) {
  if (raw == null) return null;
  if (raw is! String) {
    throw FluvieSpecError('Expected an anchor id string "track"', path: const ['track']);
  }
  return anchors.resolve(raw);
}

Path _svgPath(Object? raw) {
  if (raw is! String) {
    throw FluvieSpecError('An along animation needs an SVG "path" string', path: const ['path']);
  }
  try {
    return pathFromSvg(raw);
  } on FormatException catch (error) {
    throw FluvieSpecError(error.message, path: const ['path']);
  }
}
