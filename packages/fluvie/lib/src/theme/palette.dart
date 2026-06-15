import 'package:flutter/painting.dart' show Color;
import 'package:meta/meta.dart' show immutable;

/// The brand color palette of a `FluvieTheme`: the [bg] backdrop, the [accent]
/// brand color, the [onBg] foreground that reads on [bg], and the optional
/// [surface] / [onSurface] pair for raised panels.
///
/// This is the brand palette read via `context.fluvie.brand` — distinct from
/// the chart-series `ChartPalette` read via `context.fluvie.palette`. Elements
/// stay neutral by default; you opt a subtree in by styling at the call site,
/// for example
/// `Text('Hi', style: context.fluvie.type.title.copyWith(color: context.fluvie.brand.accent))`.
///
/// `@immutable` and value-equal by field, so two builds of the same palette
/// color identically — the frame-caching contract. [Palette.fallback]
/// gives every subtree a real dark-neutral default before any theme mounts.
///
/// ```dart
/// const Palette(bg: Color(0xFF0E0E12), accent: Color(0xFF6C5CE7), onBg: Color(0xFFFFFFFF));
/// ```
@immutable
final class Palette {
  /// Creates a palette from the required [bg], [accent], and [onBg] colors, and
  /// optional [surface] / [onSurface] colors for raised panels.
  const Palette({
    required this.bg,
    required this.accent,
    required this.onBg,
    this.surface,
    this.onSurface,
  });

  /// The neutral package default: a dark backdrop, an indigo accent, and light
  /// foreground text, matching the dark neutral the rest of the tokens use.
  const Palette.fallback()
    : bg = const Color(0xFF0E0E12),
      accent = const Color(0xFF6C5CE7),
      onBg = const Color(0xFFE0E0E0),
      surface = null,
      onSurface = null;

  /// The background color the composition paints behind its content.
  final Color bg;

  /// The brand accent color for emphasis (links, highlights, key marks).
  final Color accent;

  /// The foreground color that reads on [bg] — the default text/ink color.
  final Color onBg;

  /// The optional raised-surface color (cards, panels); `null` when unset.
  final Color? surface;

  /// The optional foreground color that reads on [surface]; `null` when unset.
  final Color? onSurface;

  /// Returns a copy with the given fields replaced; omitted fields are kept.
  ///
  /// The optional [surface] / [onSurface] cannot be cleared back to `null`
  /// through `copyWith`: passing `null` keeps the current value, matching the
  /// `copyWith` idiom across the codebase.
  Palette copyWith({
    Color? bg,
    Color? accent,
    Color? onBg,
    Color? surface,
    Color? onSurface,
  }) => Palette(
    bg: bg ?? this.bg,
    accent: accent ?? this.accent,
    onBg: onBg ?? this.onBg,
    surface: surface ?? this.surface,
    onSurface: onSurface ?? this.onSurface,
  );

  @override
  bool operator ==(Object other) =>
      other is Palette &&
      other.bg == bg &&
      other.accent == accent &&
      other.onBg == onBg &&
      other.surface == surface &&
      other.onSurface == onSurface;

  @override
  int get hashCode => Object.hash(Palette, bg, accent, onBg, surface, onSurface);

  @override
  String toString() => 'Palette(bg: $bg, accent: $accent, onBg: $onBg)';
}
