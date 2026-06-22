import 'package:flutter/widgets.dart'
    show Color, Column, MainAxisSize, SizedBox, Text, TextAlign, TextStyle;
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/core/video_size.dart';
import 'package:fluvie/src/templates/video_template.dart';
import 'package:meta/meta.dart' show immutable;

/// The props of a [TitleIntro]: a [title],
/// an optional [subtitle], and the brand [accent] / [background] colors.
///
/// `@immutable` and value-equal by field, so the same props always build the
/// same `Video` and render the same frames, so a batch caches and goldens.
/// Render one set of props for many users by mapping
/// your data onto a `TitleIntroProps` per render.
///
/// ```dart
/// const TitleIntroProps(title: '2025', subtitle: 'Year in review');
/// ```
@immutable
final class TitleIntroProps {
  /// Creates the props from a required [title] and optional [subtitle], [accent]
  /// (the title color), and [background] (the scene backdrop).
  // coverage:ignore-line: const-ctor artifact, props pinned by template tests
  const TitleIntroProps({
    required this.title,
    this.subtitle,
    this.accent = const Color(0xFFFFFFFF),
    this.background = const Color(0xFF0E0E12),
  });

  /// The headline shown large and centered; it pops in.
  final String title;

  /// The optional second line under the title; `null` shows no subtitle. When
  /// set it slides and fades in after the title settles.
  final String? subtitle;

  /// The title color — the brand accent — defaulting to white.
  final Color accent;

  /// The scene backdrop color, defaulting to the dark neutral the tokens use.
  final Color background;

  @override
  bool operator ==(Object other) =>
      other is TitleIntroProps &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.accent == accent &&
      other.background == background;

  @override
  int get hashCode => Object.hash(TitleIntroProps, title, subtitle, accent, background);

  @override
  String toString() => 'TitleIntroProps(title: $title, subtitle: $subtitle)';
}

/// A built-in intro card: a centered title
/// that pops in, with an optional subtitle that slides in after it.
///
/// Built entirely on the public element API — [Video], [Scene], `Text`,
/// [Background], [Animation.pop], [Animation.slideFade], and `.animate()` — so
/// it doubles as a worked example of a [VideoTemplate]. Render it per data row
/// with `renderTemplate(const TitleIntro(), props: ...)`.
///
/// ```dart
/// await renderTemplate(
///   const TitleIntro(),
///   props: const TitleIntroProps(title: '2025', subtitle: 'Year in review'),
///   ...,
/// );
/// ```
final class TitleIntro extends VideoTemplate<TitleIntroProps> {
  /// Creates the built-in; all variation flows through [build]'s props.
  // coverage:ignore-line: const-ctor artifact, build behavior pinned by template tests
  const TitleIntro();

  /// The intro lasts 3 seconds on the canonical vertical canvas.
  static const Time _duration = Time.seconds(3);

  @override
  Video build(TitleIntroProps props) {
    final intro = Anchor('title');
    return Video(
      size: VideoSize.reels,
      scenes: [
        Scene.centered(
          duration: _duration,
          background: Background.color(props.background),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                props.title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 96, color: props.accent),
              ).animate([Animation.pop()], anchor: intro),
              if (props.subtitle case final subtitle?) ...[
                const SizedBox(height: 24),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 36, color: props.accent),
                ).animate([
                  Animation.slideFade(at: Trigger.after(intro), delay: 0.1.seconds),
                ]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
