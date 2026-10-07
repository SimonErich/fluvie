import 'package:flutter/painting.dart' show Color, TextStyle;
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/serialization/codecs/color_codec.dart';
import 'package:fluvie/src/serialization/codecs/defaults_codec.dart';
import 'package:fluvie/src/serialization/codecs/text_style_codec.dart';

part 'theme_spec_parser.dart';

/// The deck theme: named design tokens the rest of the document references
/// instead of repeating literals — a color [palette], a type scale of text
/// styles, spacing sizes, and default animation settings.
///
/// A color field anywhere in the document may be `{"token": "<name>"}` and a
/// style object may carry a `"token"` naming a [typeScale] entry (sibling
/// literal fields win per field). Tokens resolve while the document builds,
/// inside [resolve]; an unknown name fails loudly with the known names. The
/// theme is spec data, so it counts into the render digest: retinting a token
/// re-renders everything bound to it.
final class ThemeSpec {
  /// Creates a theme from its token maps; absent maps are empty.
  ThemeSpec({
    this.palette = const {},
    this.typeScale = const {},
    this.spacing = const {},
    this.motion,
  });

  /// Reads a theme from [json]. Token names must be identifiers (letters then
  /// letters or digits) and every value must be literal — a palette entry is a
  /// hex string and a type-scale entry a literal style object, so tokens can
  /// never reference tokens. Throws a [FluvieSpecError] (located under [path])
  /// otherwise.
  factory ThemeSpec.fromJson(Map<String, Object?> json, {List<String> path = const []}) =>
      _parseTheme(json, path);

  /// The keys a theme object reads; the single source of truth for the
  /// theme's unknown-property check, in step with [ThemeSpec.fromJson].
  static const Set<String> knownKeys = {'palette', 'typeScale', 'spacing', 'motion'};

  static ThemeSpec? _current;

  /// The theme tokens currently resolve against, or null outside [resolve].
  static ThemeSpec? get current => _current;

  /// Runs [build] with [theme] as the token-resolution scope and returns its
  /// result. `VideoSpec.build` (and `deckFromSpec` in the presenter) wrap the
  /// document build in this, so every color and style decode can resolve
  /// `{"token": ...}` references; the previous scope is restored on exit.
  /// Passing null builds without a theme — token references then fail loudly.
  static T resolve<T>(ThemeSpec? theme, T Function() build) {
    final previous = _current;
    _current = theme;
    try {
      return build();
    } finally {
      _current = previous;
    }
  }

  /// The named colors; `{"token": "<name>"}` in any color field reads one.
  final Map<String, Color> palette;

  /// The named text styles; a style object's `"token"` adopts one whole,
  /// with sibling literal fields winning per field.
  final Map<String, TextStyle> typeScale;

  /// The named sizes, stored and digested for editing tools; nothing in the
  /// engine resolves them yet.
  final Map<String, double> spacing;

  /// Animation defaults the theme contributes, composing *under* the
  /// document's explicit `motionDefaults` per field (the explicit value
  /// wins); see `VideoSpec.effectiveMotionDefaults`.
  final Defaults? motion;

  /// The palette color named [name].
  ///
  /// Throws a [FluvieSpecError] (located at [path]) naming the known tokens
  /// when [name] is not in the palette.
  Color paletteColor(String name, {List<String> path = const []}) {
    final color = palette[name];
    if (color != null) return color;
    throw FluvieSpecError(
      'Unknown color token "$name"; the theme palette defines ${_names(palette.keys)}',
      path: path,
    );
  }

  /// The type-scale style named [name].
  ///
  /// Throws a [FluvieSpecError] (located at [path]) naming the known tokens
  /// when [name] is not in the type scale.
  TextStyle typeScaleStyle(String name, {List<String> path = const []}) {
    final style = typeScale[name];
    if (style != null) return style;
    throw FluvieSpecError(
      'Unknown style token "$name"; the theme type scale defines ${_names(typeScale.keys)}',
      path: path,
    );
  }

  /// The JSON form: only the non-empty token maps, canonically encoded.
  Map<String, Object?> toJson() => {
    if (palette.isNotEmpty)
      'palette': {for (final entry in palette.entries) entry.key: encodeColor(entry.value)},
    if (typeScale.isNotEmpty)
      'typeScale': {
        for (final entry in typeScale.entries) entry.key: encodeTextStyle(entry.value),
      },
    if (spacing.isNotEmpty) 'spacing': {...spacing},
    if (motion != null) 'motion': encodeDefaults(motion!),
  };

  static String _names(Iterable<String> names) {
    if (names.isEmpty) return 'no tokens';
    final sorted = names.toList()..sort();
    return sorted.map((name) => '"$name"').join(', ');
  }
}
