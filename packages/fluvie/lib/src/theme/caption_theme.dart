import 'package:fluvie/src/captions/caption_style.dart';
import 'package:meta/meta.dart';

/// The caption design tokens: the [defaultStyle] the caption layer falls back
/// to when a `Captions` track declares no `style:`.
///
/// `CaptionTheme` is part of `FluvieTokens` (read via `context.fluvie.captions`)
/// with a `Captions(style:)` override winning locally — the same precedent the
/// `code` and `mermaid` token themes set. Value-equal const, so two builds of
/// the same theme produce identical captions.
@immutable
final class CaptionTheme {
  /// Creates a theme from an explicit [defaultStyle].
  // coverage:ignore-line: const-ctor artifact, behavior pinned by caption theme tests
  const CaptionTheme({required this.defaultStyle});

  /// The standard caption theme: a plain lower-third [CaptionStyle.subtitle].
  const CaptionTheme.standard() : defaultStyle = const CaptionStyle.subtitle();

  /// The style a caption track uses when it declares none of its own.
  final CaptionStyle defaultStyle;

  @override
  bool operator ==(Object other) => other is CaptionTheme && other.defaultStyle == defaultStyle;

  @override
  int get hashCode => Object.hash(CaptionTheme, defaultStyle);

  @override
  String toString() => 'CaptionTheme(defaultStyle: $defaultStyle)';
}
