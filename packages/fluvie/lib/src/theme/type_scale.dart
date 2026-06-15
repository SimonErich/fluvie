import 'package:flutter/painting.dart' show FontWeight, TextStyle;
import 'package:meta/meta.dart' show immutable;

/// The type scale of a `FluvieTheme`: five text roles — [display], [title],
/// [headline], [body], and [caption] — derived from a single base size by a
/// geometric ratio.
///
/// Read via `context.fluvie.type` and applied at the call site, for example
/// `Text('Branded', style: context.fluvie.type.title)`. [TypeScale.fromBase]
/// builds a modular scale where each role steps the [body] size up or down by a
/// constant ratio, so the ladder is `display > title > headline > body >
/// caption`. The roles carry only [TextStyle.fontSize] and [TextStyle.fontWeight]
/// — never a font family or color — so applying a role stays composable with a
/// call-site `copyWith`.
///
/// `@immutable` and value-equal by field, so two builds of the same scale style
/// identically. [TypeScale.fallback] gives every subtree a real default
/// before any theme mounts.
///
/// ```dart
/// TypeScale.fromBase(16, ratio: 1.25);
/// ```
@immutable
final class TypeScale {
  /// Creates a scale from explicit per-role text styles.
  const TypeScale({
    required this.display,
    required this.title,
    required this.headline,
    required this.body,
    required this.caption,
  });

  /// Derives the five roles from a [base] body size and a step [ratio].
  ///
  /// The ladder is geometric around [body] (`= base`): [caption] is one step
  /// below (`base / ratio`), [headline] one step above (`base * ratio`), [title]
  /// two steps above (`base * ratio^2`), and [display] three (`base * ratio^3`).
  /// Larger roles carry a heavier [FontWeight] so a `Text` reads as a heading
  /// without any call-site weight.
  factory TypeScale.fromBase(double base, {double ratio = 1.25}) => TypeScale(
    display: TextStyle(fontSize: base * ratio * ratio * ratio, fontWeight: FontWeight.w700),
    title: TextStyle(fontSize: base * ratio * ratio, fontWeight: FontWeight.w600),
    headline: TextStyle(fontSize: base * ratio, fontWeight: FontWeight.w600),
    body: TextStyle(fontSize: base, fontWeight: FontWeight.w400),
    caption: TextStyle(fontSize: base / ratio, fontWeight: FontWeight.w400),
  );

  /// The neutral package default: the ladder [TypeScale.fromBase] derives from a
  /// 16-pixel body at the 1.25 ratio, spelled as const styles so the fallback is
  /// a compile-time value.
  const TypeScale.fallback()
    : display = const TextStyle(fontSize: 31.25, fontWeight: FontWeight.w700),
      title = const TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
      headline = const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      body = const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
      caption = const TextStyle(fontSize: 12.8, fontWeight: FontWeight.w400);

  /// The largest role — hero numbers and full-screen statements.
  final TextStyle display;

  /// The title role — scene headings and the main on-screen line.
  final TextStyle title;

  /// The headline role — a secondary line above body copy.
  final TextStyle headline;

  /// The body role at the base size — running text and labels.
  final TextStyle body;

  /// The smallest role — footnotes, attributions, and fine print.
  final TextStyle caption;

  @override
  bool operator ==(Object other) =>
      other is TypeScale &&
      other.display == display &&
      other.title == title &&
      other.headline == headline &&
      other.body == body &&
      other.caption == caption;

  @override
  int get hashCode => Object.hash(TypeScale, display, title, headline, body, caption);

  @override
  String toString() => 'TypeScale(body: ${body.fontSize}, caption: ${caption.fontSize})';
}
