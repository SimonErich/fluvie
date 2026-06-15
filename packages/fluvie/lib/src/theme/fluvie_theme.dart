import 'package:flutter/widgets.dart' show BuildContext, StatelessWidget, Widget;
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/theme/fluvie_tokens_scope.dart';
import 'package:fluvie/src/theme/palette.dart';
import 'package:fluvie/src/theme/type_scale.dart';

/// Centralizes a subtree's brand [palette], [type] scale, and [motion]
/// defaults.
///
/// Wrap a `Video` (or any subtree) to brand it: descendants read the tokens via
/// `context.fluvie`, and the resolved [motion] folds into the animation cascade
/// below `Video.motionDefaults` and above the package defaults. Each argument
/// is optional — an omitted one keeps the value of the nearest theme above, so
/// themes nest and an inner theme overrides only the fields it sets.
///
/// A `FluvieTheme` mounts a [FluvieTokensScope] over the nearest tokens, so
/// every element that already reads `context.fluvie` (charts, `Code`, `Mermaid`,
/// captions) picks the brand up without changing. Elements stay neutral by
/// default; you opt text in at the call site:
///
/// ```dart
/// FluvieTheme(
///   palette: const Palette(bg: Color(0xFF0E0E12), accent: Color(0xFF6C5CE7), onBg: Colors.white),
///   type: TypeScale.fromBase(16, ratio: 1.25),
///   motion: const Defaults(duration: Time.seconds(0.5), ease: Ease.out),
///   child: video,
/// );
///
/// Text('Branded', style: context.fluvie.type.title.copyWith(color: context.fluvie.brand.accent));
/// ```
final class FluvieTheme extends StatelessWidget {
  /// Themes [child] with an optional brand [palette], [type] scale, and [motion]
  /// defaults; each omitted field inherits from the nearest enclosing theme.
  const FluvieTheme({required this.child, this.palette, this.type, this.motion, super.key});

  /// The brand palette read via `context.fluvie.brand`; `null` inherits.
  ///
  /// This sets only the brand palette — never the chart-series `ChartPalette`
  /// read via `context.fluvie.palette`, which stays whatever the nearest theme
  /// carries.
  final Palette? palette;

  /// The type scale read via `context.fluvie.type`; `null` inherits.
  final TypeScale? type;

  /// The animation defaults folded into the cascade; `null` inherits.
  final Defaults? motion;

  /// The themed subtree.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inherited = FluvieTokensScope.of(context);
    return FluvieTokensScope(
      tokens: inherited.copyWith(brand: palette, type: type, motion: motion),
      child: child,
    );
  }
}
