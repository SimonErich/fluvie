part of 'dart_spec_printer.dart';

// The printer's half of theme tokens. Printed Dart is plain fluvie — no
// theme object exists at the widget layer — so the printer resolves every
// `{"token": ...}` to the literal the builder's `ThemeSpec` scope would use
// (`_color` reads the palette, `_textStyleArgs` the type scale) and folds the
// theme's motion defaults under the explicit ones, exactly like
// `VideoSpec.effectiveMotionDefaults`. When anything resolved, the printed
// file leads with a comment saying so.

/// The theme of the document being printed; set by [printVideoSpecJson] for
/// the duration of one print (the printer is synchronous).
_PrinterTheme? _theme;

/// The parsed theme block: palette and type-scale lookups plus the motion
/// defaults, tracking whether anything actually resolved.
final class _PrinterTheme {
  _PrinterTheme(this.palette, this.typeScale, this.motion);

  /// Reads the `theme` block of [spec], or null when the document has none.
  static _PrinterTheme? of(Map<String, Object?> spec) {
    final theme = spec['theme'];
    if (theme is! Map<String, Object?>) return null;
    final palette = theme['palette'];
    final typeScale = theme['typeScale'];
    final motion = theme['motion'];
    return _PrinterTheme(
      palette is Map<String, Object?> ? palette : const {},
      typeScale is Map<String, Object?> ? typeScale : const {},
      motion is Map<String, Object?> ? motion : null,
    );
  }

  final Map<String, Object?> palette;
  final Map<String, Object?> typeScale;
  final Map<String, Object?>? motion;

  /// Whether any token resolved (or the motion composed) into the output.
  bool resolved = false;

  /// The literal hex behind the palette token [name].
  String color(String name) {
    final hex = palette[name];
    if (hex is! String) {
      throw FormatException('Unknown color token "$name"; the palette defines ${_names(palette)}');
    }
    resolved = true;
    return hex;
  }

  /// The literal style map behind [raw]'s `token`, merged under its sibling
  /// literal fields — a literal always wins per field.
  Map<String, Object?> style(Map<String, Object?> raw) {
    final name = raw['token'];
    final base = name is String ? typeScale[name] : null;
    if (base is! Map<String, Object?>) {
      throw FormatException(
        'Unknown style token "$name"; the type scale defines ${_names(typeScale)}',
      );
    }
    resolved = true;
    return {
      ...base,
      for (final entry in raw.entries)
        if (entry.key != 'token') entry.key: entry.value,
    };
  }

  static String _names(Map<String, Object?> tokens) {
    if (tokens.isEmpty) return 'no tokens';
    final sorted = tokens.keys.toList()..sort();
    return sorted.map((name) => '"$name"').join(', ');
  }
}

/// Resolves a `{"token": "<name>"}` color reference to its literal hex.
String _tokenColor(Map<String, Object?> raw) {
  final token = raw['token'];
  if (token is! String || raw.length != 1) {
    throw const FormatException('A color token reference is exactly {"token": "<name>"}');
  }
  final theme = _theme;
  if (theme == null) {
    throw FormatException('Color token "$token" cannot resolve: the document has no theme');
  }
  return theme.color(token);
}

/// A style map with any type-scale `token` resolved to its literal base;
/// a token-free style passes through untouched.
Map<String, Object?> _resolvedStyle(Map<String, Object?> style) {
  if (!style.containsKey('token')) return style;
  final theme = _theme;
  if (theme == null) {
    throw FormatException(
      'Style token "${style['token']}" cannot resolve: the document has no theme',
    );
  }
  return theme.style(style);
}

/// The `motionDefaults` map to print: the theme's motion composed under the
/// document's explicit defaults per field — the builder's
/// `effectiveMotionDefaults`, over JSON.
Map<String, Object?>? _effectiveMotionDefaults(Map<String, Object?> spec) {
  final explicit = spec['motionDefaults'];
  final explicitMap = explicit is Map<String, Object?> ? explicit : null;
  final themeMotion = _theme?.motion;
  if (themeMotion == null) return explicitMap;
  _theme!.resolved = true;
  return {...themeMotion, ...?explicitMap};
}
