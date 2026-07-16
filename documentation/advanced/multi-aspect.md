# Multi-aspect

Write a video once, render it to reels, square, landscape, and portrait. An
`Adaptive` widget branches its layout per aspect, and `render(video, aspect:)`
picks the variant. Lesson 11 lays one subtree out four ways:

<!-- code-excerpt "examples/gallery/lib/lessons/11_templates_and_aspects.dart (adaptive)" -->
```dart
child: Adaptive(
  reels: () => _aspectStack('Built for reels'),
  portrait45: () => _aspectStack('Built for 4:5'),
  square: () => _aspectStack('Built for square'),
  landscape: () => _aspectRow('Built for landscape'),
),
```

Each branch is a builder of plain content. The tall aspects stack their blocks;
the landscape aspect places them side by side. The rest of this page covers the
four aspects, rendering each one, and what stays the same across them.

## The four aspects

`Aspect` names the aspect-ratio families:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_11_snippets.dart (aspect-families)" -->
```dart
Aspect.reels, // vertical 9:16, for Reels, Shorts, TikTok, Stories
Aspect.square, // 1:1, for feed posts
Aspect.landscape, // horizontal 16:9, for YouTube, presentations, TV
Aspect.portrait45, // vertical 4:5, the tall feed-post format
```

`reels` is the default when nothing sets an aspect. Each aspect derives its
canvas size from a long edge, so the same long edge gives a `1080 by 1920` reel
and a `1920 by 1080` landscape frame.

## Rendering each aspect

`render(video, aspect:)` re-derives the canvas size from the aspect and renders
the composition for it. Loop over the aspects to fan one definition out:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_14_snippets.dart (render-aspect)" -->
```dart
Future<void> renderForAspects({
  required Widget composition,
  required RenderService service,
  required ShellMount pumpWidget,
  required ShellFramePump pumpFrame,
}) async {
  for (final aspect in [Aspect.reels, Aspect.square, Aspect.landscape, Aspect.portrait45]) {
    await render(
      composition: composition,
      aspect: aspect,
      frameCount: 90,
      outDir: Directory('out/${aspect.name}'),
      service: service,
      pumpWidget: pumpWidget,
      pumpFrame: pumpFrame,
    );
  }
}
```

`render` ignores any size the composition declares for itself and uses the
aspect's size instead. It mounts the aspect over the tree, so every `Adaptive`
branch and every `AspectScope.of` read picks the variant for the render in progress.
The `service`, `pumpWidget`, and `pumpFrame` are the host's render wiring. A host
that already has a `Video` should reach for `renderVideo(video:, aspect:)`
instead: it takes the same aspect and derives everything else from the video. See
[the rendering surface](../reference/rendering-surface.md).

From the command line, the same job is one flag:

```sh
fluvie render ./lib/my_video.dart --out landscape.mp4 --aspect landscape
```

## Branching at build time

`Adaptive` covers a whole subtree. When one element wants to branch its own
layout, read the aspect directly with `AspectScope.of(context)`:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_14_snippets.dart (aspect-of)" -->
```dart
Widget headlineForAspect() => Builder(
  builder: (context) {
    final wide = AspectScope.of(context) == Aspect.landscape;
    return Text(
      wide ? 'Wide cut' : 'Tall cut',
      style: const TextStyle(fontSize: 64, color: Color(0xFFE6EDF3)),
    );
  },
);
```

`AspectScope.of` never throws. Outside a render, or in a plain preview, it returns
`Aspect.reels`, so an element always has a sane default.

One rule for `Adaptive`: every aspect you render needs a matching branch. A null
branch for the aspect under render throws an `ArgumentError` at build time, so
a missing layout fails loudly rather than rendering nothing.

## Timing is the same across aspects

The headline contract: only the layout branches. The timing does not. The same
plan resolves for every aspect, so an animation that starts at 0.5 seconds and
runs for 1 second starts and runs the same in the reel and in the landscape cut.
The aspects share one clock and differ only in shape.

This holds because `render` re-derives the canvas size and re-runs layout per
aspect, but resolves the same schedule. A trigger that fires after another
element fires at the same frame in every aspect. A stagger keeps its step. What
changes between a tall cut and a wide cut is where things sit, never when they
happen.

Each aspect renders on its own terms. The per-aspect renders each carry their own
size in the cache key, so the reel and the landscape cut cache separately and
never collide.

## Where to next

- [Templates](templates.md): pair multi-aspect with a data-driven template to
  fan one definition across formats and rows.
- [Theming](theming.md): brand every aspect from one palette and type scale.
