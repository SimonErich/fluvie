import 'package:flutter/widgets.dart'
    show Color, Column, MainAxisSize, SizedBox, Text, TextAlign, TextStyle;
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/video_size.dart';
import 'package:fluvie/src/elements/counter.dart';
import 'package:fluvie/src/templates/video_template.dart';
import 'package:meta/meta.dart' show immutable;

/// The props of a [StatHighlight]: the
/// [value] the headline counts to, its [label], and the brand [accent] /
/// [background] colors.
///
/// `@immutable` and value-equal by field, so the same props always build the
/// same `Video` and render the same frames, so a batch caches and goldens.
/// Generate one stat reel per metric by mapping each
/// data row onto a `StatHighlightProps`.
///
/// ```dart
/// const StatHighlightProps(value: 48230, label: 'minutes listened');
/// ```
@immutable
final class StatHighlightProps {
  /// Creates the props from a required [value] and [label] and optional [accent]
  /// (the headline color) and [background] (the scene backdrop).
  // coverage:ignore-line const ctor artifact props pinned by template tests
  const StatHighlightProps({
    required this.value,
    required this.label,
    this.accent = const Color(0xFF55EFC4),
    this.background = const Color(0xFF0E0E12),
  });

  /// The number the headline counts up to.
  final num value;

  /// The caption shown beneath the headline (for example `'minutes listened'`).
  final String label;

  /// The headline color — the brand accent — defaulting to a mint green.
  final Color accent;

  /// The scene backdrop color, defaulting to the dark neutral the tokens use.
  final Color background;

  @override
  bool operator ==(Object other) =>
      other is StatHighlightProps &&
      other.value == value &&
      other.label == label &&
      other.accent == accent &&
      other.background == background;

  @override
  int get hashCode => Object.hash(StatHighlightProps, value, label, accent, background);

  @override
  String toString() => 'StatHighlightProps(value: $value, label: $label)';
}

/// A built-in stat card: a [Counter]
/// headline counting up to a value, with its label beneath.
///
/// Built entirely on the public element API — [Video], [Scene], [Counter],
/// `Text`, [Background], and `.animate()` — so it doubles as a worked example of
/// a [VideoTemplate]. Render it per data row with
/// `renderTemplate(const StatHighlight(), props: ...)`.
///
/// ```dart
/// await renderTemplate(
///   const StatHighlight(),
///   props: const StatHighlightProps(value: 48230, label: 'minutes listened'),
///   ...,
/// );
/// ```
final class StatHighlight extends VideoTemplate<StatHighlightProps> {
  /// Creates the built-in; all variation flows through [build]'s props.
  // coverage:ignore-line const ctor artifact build behavior pinned by template tests
  const StatHighlight();

  /// The card lasts 3 seconds; the count runs over the first 2.
  static const Time _duration = Time.seconds(3);

  /// How long the headline takes to count up to its value.
  static const Time _countDuration = Time.seconds(2);

  @override
  Video build(StatHighlightProps props) => Video(
    size: VideoSize.reels,
    scenes: [
      Scene.centered(
        duration: _duration,
        background: Background.color(props.background),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Counter(
              to: props.value,
              duration: _countDuration,
              style: TextStyle(fontSize: 120, color: props.accent),
            ),
            const SizedBox(height: 24),
            Text(
              props.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 36, color: Color(0xFFE0E0E0)),
            ).animate([Animation.fadeIn(delay: _countDuration)]),
          ],
        ),
      ),
    ],
  );
}
