import 'package:flutter/painting.dart' show Color;
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/elements/chart/palette/chart_palette.dart';
import 'package:fluvie/src/elements/code/theme/code_theme.dart';
import 'package:fluvie/src/elements/mermaid/mermaid_theme.dart';
import 'package:fluvie/src/theme/caption_theme.dart';
import 'package:fluvie/src/theme/palette.dart';
import 'package:fluvie/src/theme/type_scale.dart';
import 'package:meta/meta.dart' show immutable, useResult;

export 'package:fluvie/src/elements/chart/palette/chart_palette.dart' show ChartPalette;
export 'package:fluvie/src/elements/code/theme/code_theme.dart' show CodeTheme;
export 'package:fluvie/src/elements/mermaid/mermaid_theme.dart' show MermaidTheme;
export 'package:fluvie/src/theme/caption_theme.dart' show CaptionTheme;

/// The neutral series palette behind [FluvieTokens.fallback] — six distinct,
/// readable hues that cycle for any number of chart segments.
const ChartPalette _fallbackPalette = ChartPalette([
  Color(0xFF6C5CE7), // indigo
  Color(0xFF00B894), // teal
  Color(0xFFE17055), // coral
  Color(0xFFFDCB6E), // amber
  Color(0xFF0984E3), // blue
  Color(0xFFE84393), // magenta
]);

/// The design tokens elements read for color, type, and motion: the value a
/// `FluvieTheme` mounts and `context.fluvie` resolves.
///
/// The full surface carries three groups. The brand group is the [brand]
/// [Palette] (bg / accent / onBg), the [type] [TypeScale], and the [motion]
/// [Defaults] a `FluvieTheme` folds into the animation cascade. The element group
/// is the chart-series [palette] plus the [axisColor], [gridColor], and
/// [labelColor] charts paint with, the [code] theme `Code` / `Terminal` color
/// with, the [mermaid] theme diagrams render with, and the [captions] theme.
///
/// Note the deliberate name split: [palette] is the chart-series [ChartPalette]
/// (the colors a chart cycles through), while [brand] is the brand
/// [Palette] read via `context.fluvie.brand.accent`. The two never collide.
///
/// A subtree with no theme uses [FluvieTokens.fallback], so every element has a
/// real default before any `FluvieTheme` mounts. Tokens are value-equal by
/// field, so two builds of the same theme produce identical geometry — the
/// frame-caching contract.
///
/// ```dart
/// const tokens = FluvieTokens.fallback();
/// final seriesColor = tokens.palette.colorAt(seriesIndex);
/// final accent = tokens.brand.accent;
/// ```
@immutable
final class FluvieTokens {
  /// Creates tokens from an explicit series [palette], axis / grid / label
  /// colors, an optional [code] / [mermaid] / [captions] theme, and the
  /// brand group [brand] / [type] / [motion], each defaulting to its neutral
  /// fallback so every prior call site compiles unchanged.
  const FluvieTokens({
    required this.palette,
    required this.axisColor,
    required this.gridColor,
    required this.labelColor,
    this.code = const CodeTheme.dark(),
    this.mermaid = const MermaidTheme.dark(),
    this.captions = const CaptionTheme.standard(),
    this.brand = const Palette.fallback(),
    this.type = const TypeScale.fallback(),
    this.motion = const Defaults(),
  });

  /// The neutral package defaults: a six-hue series [palette], muted grey axis,
  /// grid, and label colors, the dark [code] / [mermaid] themes, the standard
  /// [captions] theme, the dark-neutral [brand] [Palette], the [TypeScale]
  /// fallback ladder, and an unset [motion] (the package animation defaults
  /// govern until a `FluvieTheme` sets one).
  const FluvieTokens.fallback()
    : palette = _fallbackPalette,
      axisColor = const Color(0xFF9E9E9E),
      gridColor = const Color(0x33FFFFFF),
      labelColor = const Color(0xFFE0E0E0),
      code = const CodeTheme.dark(),
      mermaid = const MermaidTheme.dark(),
      captions = const CaptionTheme.standard(),
      brand = const Palette.fallback(),
      type = const TypeScale.fallback(),
      motion = const Defaults();

  /// The ordered chart-series colors a chart cycles through.
  final ChartPalette palette;

  /// The color of the chart axes (the value and category baselines).
  final Color axisColor;

  /// The color of the background gridlines drawn behind the plot.
  final Color gridColor;

  /// The color of axis tick labels and the legend text.
  final Color labelColor;

  /// The theme `Code` and `Terminal` color with; defaults to
  /// [CodeTheme.dark].
  final CodeTheme code;

  /// The theme `Mermaid` renders diagrams with; defaults to
  /// [MermaidTheme.dark].
  final MermaidTheme mermaid;

  /// The caption design tokens the caption layer falls back to when a
  /// `Captions` track declares no `style:`; defaults to
  /// [CaptionTheme.standard].
  final CaptionTheme captions;

  /// The brand palette read via `context.fluvie.brand` — distinct from the
  /// chart-series [palette]; defaults to [Palette.fallback].
  final Palette brand;

  /// The type scale read via `context.fluvie.type`; defaults to
  /// [TypeScale.fallback].
  final TypeScale type;

  /// The theme's animation defaults: the cascade layer below
  /// `Video.motionDefaults` and above the package defaults. An unset
  /// (all-null) [Defaults] leaves the cascade unchanged.
  final Defaults motion;

  /// Returns a copy with the given fields replaced; omitted fields are kept.
  @useResult
  FluvieTokens copyWith({
    ChartPalette? palette,
    Color? axisColor,
    Color? gridColor,
    Color? labelColor,
    CodeTheme? code,
    MermaidTheme? mermaid,
    CaptionTheme? captions,
    Palette? brand,
    TypeScale? type,
    Defaults? motion,
  }) => FluvieTokens(
    palette: palette ?? this.palette,
    axisColor: axisColor ?? this.axisColor,
    gridColor: gridColor ?? this.gridColor,
    labelColor: labelColor ?? this.labelColor,
    code: code ?? this.code,
    mermaid: mermaid ?? this.mermaid,
    captions: captions ?? this.captions,
    brand: brand ?? this.brand,
    type: type ?? this.type,
    motion: motion ?? this.motion,
  );

  @override
  bool operator ==(Object other) =>
      other is FluvieTokens &&
      other.palette == palette &&
      other.axisColor == axisColor &&
      other.gridColor == gridColor &&
      other.labelColor == labelColor &&
      other.code == code &&
      other.mermaid == mermaid &&
      other.captions == captions &&
      other.brand == brand &&
      other.type == type &&
      other.motion == motion;

  @override
  int get hashCode => Object.hash(
    FluvieTokens,
    palette,
    axisColor,
    gridColor,
    labelColor,
    code,
    mermaid,
    captions,
    brand,
    type,
    motion,
  );

  @override
  String toString() =>
      'FluvieTokens(palette: $palette, brand: $brand, type: $type, motion: $motion, '
      'code: $code, mermaid: $mermaid, captions: $captions)';
}
