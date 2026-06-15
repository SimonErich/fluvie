import 'package:flutter/widgets.dart' show BuildContext, InheritedWidget;
import 'package:fluvie/src/theme/fluvie_tokens.dart';

/// Carries [FluvieTokens] down the tree so charts and captions can read
/// theme colors via `context.fluvie`.
///
/// Unlike the frame clock's `FrameProvider`, tokens are optional: a chart with
/// no scope above it falls back to `const FluvieTokens.fallback()` rather than
/// raising. That makes [of] total — it never throws — which keeps every chart
/// usable without a theme.
///
/// A `FluvieTheme` mounts one of these so `context.fluvie` resolves the full
/// theme without any chart changing: charts read [FluvieTokens] either way.
/// Wrap a subtree to brand its charts:
///
/// ```dart
/// FluvieTokensScope(
///   tokens: const FluvieTokens(
///     palette: ChartPalette([Color(0xFF6C5CE7), Color(0xFF00B894)]),
///     axisColor: Color(0xFF9E9E9E),
///     gridColor: Color(0x33FFFFFF),
///     labelColor: Color(0xFFE0E0E0),
///   ),
///   child: myChart,
/// )
/// ```
final class FluvieTokensScope extends InheritedWidget {
  /// Provides [tokens] to every descendant of `child`.
  const FluvieTokensScope({required this.tokens, required super.child, super.key});

  /// The design tokens visible to this subtree.
  final FluvieTokens tokens;

  /// The nearest tokens above [context], or `const FluvieTokens.fallback()`
  /// when there is no scope.
  ///
  /// This never throws: tokens are optional, so a chart outside any scope still
  /// has a real default to color with.
  static FluvieTokens of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FluvieTokensScope>()?.tokens ??
      const FluvieTokens.fallback();

  @override
  bool updateShouldNotify(FluvieTokensScope oldWidget) => oldWidget.tokens != tokens;
}
