// Compiled, tested snippets for the theming, templates, and
// multi-aspect docs. They live here, not hand-typed in Markdown, so the
// documentation never drifts from a real API. Each `#docregion` flows into one
// fence via a `<!-- code-excerpt -->` marker.

import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:fluvie/fluvie.dart';

/// A `FluvieTheme` brands a subtree from one palette, type scale, and motion
/// default; descendants read the tokens from `context.fluvie`.
Widget brandedSubtree(Widget video) =>
    // #docregion fluvie-theme
    FluvieTheme(
      palette: const Palette(
        bg: Color(0xFF0E1116),
        accent: Color(0xFF55EFC4),
        onBg: Color(0xFFE6EDF3),
      ),
      type: TypeScale.fromBase(40, ratio: 1.3),
      motion: const Defaults(duration: Time.seconds(0.5), ease: Ease.out),
      child: video,
    );
// #enddocregion fluvie-theme

/// The brand color set: a backdrop, an accent, the foreground that reads on the
/// backdrop, and an optional raised-surface pair.
Palette brandPalette() =>
    // #docregion palette
    const Palette(
      bg: Color(0xFF0E1116), // the backdrop
      accent: Color(0xFF55EFC4), // the brand color for emphasis
      onBg: Color(0xFFE6EDF3), // the foreground that reads on bg
      surface: Color(0xFF1A1F26), // optional: a raised-panel color
      onSurface: Color(0xFFE6EDF3), // optional: the ink on a surface
    );
// #enddocregion palette

/// Reading brand colors at the call site through `context.fluvie.brand`.
List<Color> brandColors(BuildContext context) => [
  // #docregion brand-access
  context.fluvie.brand.bg,
  context.fluvie.brand.accent,
  context.fluvie.brand.onBg,
  // #enddocregion brand-access
];

/// `TypeScale.fromBase` derives five roles from one base size and a ratio.
TypeScale typeLadder() =>
    // #docregion type-scale
    TypeScale.fromBase(40, ratio: 1.3);
// #enddocregion type-scale

/// The five text roles, largest to smallest, read from `context.fluvie.type`.
List<TextStyle> typeRoles(BuildContext context) => [
  // #docregion type-roles
  context.fluvie.type.display, // hero numbers and full-screen statements
  context.fluvie.type.title, // scene headings and the main on-screen line
  context.fluvie.type.headline, // a secondary line above body copy
  context.fluvie.type.body, // running text and labels, at the base size
  context.fluvie.type.caption, // footnotes, attributions, fine print
  // #enddocregion type-roles
];

/// Themed text that reads the display role and the brand accent at the call
/// site, then pops in.
Widget themedText() =>
    // #docregion themed-text
    Builder(
      builder: (context) => Text(
        'One definition,\nmany formats',
        textAlign: TextAlign.center,
        style: context.fluvie.type.display.copyWith(color: context.fluvie.brand.accent),
      ).animate([Animation.pop()]),
    );
// #enddocregion themed-text

/// The aspect-ratio families a multi-aspect render fans out to.
List<Aspect> aspectFamilies() => const [
  // #docregion aspect-families
  Aspect.reels, // vertical 9:16, for Reels, Shorts, TikTok, Stories
  Aspect.square, // 1:1, for feed posts
  Aspect.landscape, // horizontal 16:9, for YouTube, presentations, TV
  Aspect.portrait45, // vertical 4:5, the tall feed-post format
  // #enddocregion aspect-families
];

/// The two built-in template props, ready to hand to their templates.
TitleIntroProps titleProps() =>
    // #docregion title-props
    const TitleIntroProps(title: '2025', subtitle: 'Year in review');
// #enddocregion title-props

StatHighlightProps statProps() =>
    // #docregion stat-props
    const StatHighlightProps(value: 48230, label: 'minutes listened');
// #enddocregion stat-props
