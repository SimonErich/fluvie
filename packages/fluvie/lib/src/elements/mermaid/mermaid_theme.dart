import 'package:meta/meta.dart' show immutable;

/// The theme a `Mermaid` diagram is rendered with.
///
/// A `MermaidTheme` carries the Mermaid built-in [variant] (the `theme:` value
/// Mermaid's renderer understands, for example `dark` or `base`) and the
/// [themeVariables] map that overrides individual diagram colors. It is part of
/// `FluvieTokens` (read via `context.fluvie.mermaid`), with a `Mermaid(theme:)`
/// override winning locally.
///
/// `@immutable` and value-equal by field, so two builds of the same theme
/// rasterize to the same diagram and share one snapshot cache entry. The theme
/// folds into the snapshot key through [cacheKey]: a canonical, order-
/// independent encoding of the variant and variables, computed without a
/// `BuildContext` so the collect pass can key the diagram before the frame loop.
/// Ship [MermaidTheme.dark] / [MermaidTheme.light] presets, or build a custom
/// theme.
///
/// ```dart
/// const Mermaid('graph TD; A-->B;', theme: MermaidTheme.light());
/// ```
@immutable
final class MermaidTheme {
  /// Creates a theme from the Mermaid built-in [variant] and an optional map of
  /// [themeVariables] overrides (defaulting to no overrides).
  const MermaidTheme({required this.variant, this.themeVariables = const {}});

  /// A neutral dark theme: light diagram lines and text on a dark background.
  const MermaidTheme.dark()
    : variant = 'dark',
      themeVariables = const {
        'primaryColor': '#2d2d2d',
        'primaryTextColor': '#e0e0e0',
        'lineColor': '#9e9e9e',
        'background': '#1e1e1e',
      };

  /// A neutral light theme: dark diagram lines and text on a light background.
  const MermaidTheme.light()
    : variant = 'base',
      themeVariables = const {
        'primaryColor': '#ffffff',
        'primaryTextColor': '#1e1e1e',
        'lineColor': '#333333',
        'background': '#ffffff',
      };

  /// The Mermaid built-in theme name handed to the renderer's `theme:` option.
  final String variant;

  /// The per-variable color overrides handed to Mermaid's `themeVariables`.
  final Map<String, String> themeVariables;

  /// The canonical, order-independent string that fully identifies this theme's
  /// pixels — the [variant] followed by every variable in sorted-key order.
  ///
  /// `Mermaid` folds this into the snapshot cache key, so two themes with the
  /// same variant and variables (in any map order) share one cache entry while
  /// any change produces a distinct one. It is pure and `BuildContext`-free.
  String get cacheKey {
    final keys = themeVariables.keys.toList()..sort();
    final pairs = [for (final key in keys) '$key=${themeVariables[key]}'];
    return 'mermaidTheme|$variant|${pairs.join(',')}';
  }

  @override
  bool operator ==(Object other) => other is MermaidTheme && other.cacheKey == cacheKey;

  @override
  int get hashCode => cacheKey.hashCode;

  @override
  String toString() => 'MermaidTheme($variant)';
}
