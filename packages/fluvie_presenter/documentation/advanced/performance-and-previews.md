# Performance and previews

The presenter's rule: nothing renders twice, and nothing renders on the
presenting path that does not have to.

## What runs while you present

One slide is mounted at a time, on one clock. A slide change mounts the next
composition and unmounts the outgoing one when the blend ends. Steps do not
re-resolve the slide; a reveal mounts just the stopped subtree and resolves
it locally, so a click costs one small mount, not a recompile.

The chrome rebuilds on state changes, not on frames. Per-frame updates flow
through the frame provider to the stage alone; the counter, sidebar, and
notes panel listen to position changes only.

## How previews render

Sidebar and overview thumbnails come from one shared service. Each preview
is the slide's settled final state, rendered once on a hidden host behind
the opaque stage, captured as an image, and cached (an LRU, 32 slides by
default). Requests deduplicate while in flight and run one at a time, so a
fast scroll through the sidebar queues work instead of stampeding it.

Tiles show a flat placeholder until their image lands and repaint by
themselves. Presenting never waits for a preview.

Warming the whole deck up front is one call away when you want it, off the
critical path:

```text
service.pregenerateAll(slideCount)
```

(The shell exposes the service through `slidePreviewServiceProvider`.)

Previews regenerate when the deck instance changes; swapping the `Video`
you passed to `FluvieSlides` resets the whole presentation scope, caches
included.

## Deck habits that stay fast

- Prefer absolute times (`1.seconds`) in decks; they resolve once and stay
  put.
- Big media belongs in slides that need it, not on slide one; each slide
  mounts on entry.
- Ambient loops are cheap (pure functions of the frame), so keep the motion
  that makes slides feel alive.

## Where to next

- [Sidebar and overview](../guides/sidebar-and-overview.md): the consumer
  view of the cache.
- [How stepping works](how-stepping-works.md): why holds cost nothing.
