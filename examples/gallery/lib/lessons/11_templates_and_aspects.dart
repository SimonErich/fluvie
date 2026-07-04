import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/lessons/lesson.dart';

/// The brand this lesson themes everything with: one [Palette]
/// and one [TypeScale] flow through `context.fluvie`, so the title and the label
/// pick the brand accent and the type ladder up at the call site — no per-widget
/// color or font size.
// #docregion theme
const _brand = Palette(
  bg: Color(0xFF0E1116),
  accent: Color(0xFF55EFC4),
  onBg: Color(0xFFE6EDF3),
);
final _type = TypeScale.fromBase(40, ratio: 1.3);
// #enddocregion theme

/// The data the [StatHighlight] template renders into a card — change the props
/// and the same template builds a different card, byte-identically.
// #docregion stat-props
const _stat = StatHighlightProps(value: 48230, label: 'minutes listened');
// #enddocregion stat-props

/// The animations the aspect branches bind, hoisted to stable instances so the
/// `Adaptive`/`Builder` rebuild every frame reuses the **same** `List<Animation>`
/// (the determinism contract: `.animate()`'s animations must be stable across
/// frames — a fresh list literal inside a per-frame builder would re-register a
/// new token after resolution and throw).
final List<Animation> _slideFade = [Animation.slideFade()];
final List<Animation> _pop = [Animation.pop()];

/// Lesson 11 — templates, aspects, and theme: a built-in
/// [StatHighlight] template card, an [Adaptive] layout that branches per aspect,
/// and a [FluvieTheme] whose brand drives the colors and the type scale.
///
/// Every input is pure authoring data, so the lesson renders offline and
/// deterministically: the template builds the same scenes from the same props,
/// the `Adaptive` branch is chosen from the rendered aspect, and the theme reads
/// resolve at build time with no IO and no wall-clock.
const lesson11TemplatesAndAspects = Lesson(
  id: '11_templates_and_aspects',
  title: 'Templates, aspects, and theme',
  intro:
      'A built-in StatHighlight template renders a card from data, an Adaptive '
      'layout branches across aspect ratios, and a FluvieTheme brand drives the '
      'colors and the type scale through context.fluvie. One definition, '
      'data-driven and aspect-aware, themed from a single palette.',
  video: lesson11Video,
);

/// Builds the lesson 11 composition: a three-scene, 9 second vertical reel,
/// themed by one [FluvieTheme].
///
/// Scene 1 reuses the [StatHighlight] built-in template (a [VideoTemplate]):
/// `const StatHighlight().build(props)` returns a whole `Video`, and the lesson
/// lifts its single scene so the template's card opens the reel. Scene 2 is an
/// [Adaptive] subtree that lays out vertically for `reels`/`portrait45`, side by
/// side for `landscape`, and stacked for `square` — only the layout branches,
/// the timing is identical across aspects. Scene 3 is plain themed text reading
/// the brand and the type scale from `context.fluvie`. `poster: 1.seconds` lands
/// on the stat card mid-count.
Video lesson11Video() {
  return Video(
    size: VideoSize.reels,
    poster: 1.seconds,
    transition: Transition.crossFade(0.4.seconds),
    scenes: [
      _statCardScene(),
      _adaptiveScene(),
      _themedOutroScene(),
    ],
  );
}

/// Scene 1: the built-in [StatHighlight] template, rendered from [_stat].
///
/// A [VideoTemplate.build] returns a complete `Video`; this lesson lifts its one
/// scene so the data-driven card composes into the reel. Swap [_stat] and the
/// same template builds a different card with no other change.
// #docregion template
Scene _statCardScene() => const StatHighlight().build(_stat).scenes.single;
// #enddocregion template

/// Scene 2: an [Adaptive] layout that branches across aspect ratios.
///
/// Each branch is a builder of plain content; `.animate()` adds the motion. A
/// preview and the gallery golden render the canonical vertical `reels`, so the
/// `reels` branch is what shows here; a `render(video, aspect: Aspect.landscape)`
/// would pick the side-by-side branch instead, with the same timing.
Scene _adaptiveScene() => Scene(
  duration: 3.seconds,
  background: Background.color(_brand.bg),
  children: [
    Center(
      child: FluvieTheme(
        palette: _brand,
        type: _type,
        // #docregion adaptive
        child: Adaptive(
          reels: () => _aspectStack('Built for reels'),
          portrait45: () => _aspectStack('Built for 4:5'),
          square: () => _aspectStack('Built for square'),
          landscape: () => _aspectRow('Built for landscape'),
        ),
        // #enddocregion adaptive
      ),
    ),
  ],
);

/// The tall branch: a centered column of two themed blocks above a caption.
Widget _aspectStack(String label) => Builder(
  builder: (context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _brandBlock(),
      const SizedBox(height: 32),
      _brandBlock(),
      const SizedBox(height: 48),
      Text(label, style: context.fluvie.type.headline.copyWith(color: context.fluvie.brand.onBg)),
    ],
  ),
).animate(_slideFade);

/// The wide branch: the same two blocks placed side by side for landscape.
Widget _aspectRow(String label) => Builder(
  builder: (context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [_brandBlock(), const SizedBox(width: 32), _brandBlock()],
      ),
      const SizedBox(height: 48),
      Text(label, style: context.fluvie.type.headline.copyWith(color: context.fluvie.brand.onBg)),
    ],
  ),
).animate(_slideFade);

/// One accent-tinted block, sized in absolute pixels so every aspect lays it out
/// the same way.
Widget _brandBlock() => Builder(
  builder: (context) => Container(
    width: 220,
    height: 220,
    decoration: BoxDecoration(
      color: context.fluvie.brand.accent,
      borderRadius: BorderRadius.circular(24),
    ),
  ),
);

/// Scene 3: plain themed text reading the brand and the type scale from
/// `context.fluvie` (text opts in at the call site).
Scene _themedOutroScene() => Scene.centered(
  duration: 3.seconds,
  background: Background.color(_brand.bg),
  child: FluvieTheme(
    palette: _brand,
    type: _type,
    // #docregion themed-text
    child: Builder(
      builder: (context) => Text(
        'One definition,\nmany formats',
        textAlign: TextAlign.center,
        style: context.fluvie.type.display.copyWith(color: context.fluvie.brand.accent),
      ).animate(_pop),
    ),
    // #enddocregion themed-text
  ),
);
