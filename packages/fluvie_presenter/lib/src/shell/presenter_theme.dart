import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData;

/// The presenter's look: obers_ui tokens for the chrome, plus the one color
/// the chrome does not own — the stage behind the letterboxed slide.
///
/// The default is flat and dark, which is what a room full of people looking
/// at a projector wants. Hand `FluvieSlides(theme: ...)` your own tokens to
/// brand the chrome:
///
/// ```dart
/// FluvieSlides(video, theme: PresenterTheme(tokens: OiThemeData.dark()));
/// ```
final class PresenterTheme {
  /// Creates a theme; both parts have flat dark defaults.
  const PresenterTheme({this.tokens, this.stageBackground = const Color(0xFF101014)});

  /// The obers_ui tokens the chrome renders with, or `null` for the dark
  /// defaults.
  final OiThemeData? tokens;

  /// The stage color behind the letterboxed slide.
  final Color stageBackground;

  /// The tokens with the default applied — what the shell actually mounts.
  OiThemeData resolveTokens() => tokens ?? OiThemeData.dark();
}

/// The active [PresenterTheme]; the shell overrides it from
/// `FluvieSlides(theme: ...)`.
final presenterThemeProvider = Provider<PresenterTheme>((ref) => const PresenterTheme());
