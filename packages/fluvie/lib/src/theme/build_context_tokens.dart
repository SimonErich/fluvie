import 'package:flutter/widgets.dart' show BuildContext;
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/theme/fluvie_tokens_scope.dart';

/// The `context.fluvie` accessor: the design tokens elements read
/// for color, type, and motion.
///
/// It resolves the nearest [FluvieTokensScope], falling back to
/// `const FluvieTokens.fallback()` when none is present, so it always returns a
/// usable theme:
///
/// ```dart
/// final color = context.fluvie.palette.colorAt(seriesIndex);
/// ```
///
/// The returned [FluvieTokens] is the full surface a `FluvieTheme` mounts:
/// the chart-series palette plus the axis / grid / label colors, the code /
/// mermaid / captions themes, and the brand `Palette` (`context.fluvie.brand`),
/// `TypeScale` (`context.fluvie.type`), and motion `Defaults` of the brand group.
extension FluvieContext on BuildContext {
  /// The design tokens visible at this context (the nearest scope or the
  /// package fallback).
  FluvieTokens get fluvie => FluvieTokensScope.of(this);
}
