# Sidebar and overview

Big decks need a map. The presenter gives you two.

**The sidebar** (press **T**, or start with `showSidebar: true`) lists every
slide as a thumbnail down the left. The current slide wears the accent
border and stays in view as you move. Click any slide to jump to it; the
jump is instant and lands on the slide's base step.

**The overview** (press **O**) covers the stage with a grid of every slide.
Pick one to jump and close; Esc just closes. It is the "where was that
chart" key.

Both share one preview cache. Thumbnails render lazily, off the presenting
path: a tile shows a flat placeholder until its image lands, then repaints
by itself. Each preview is the slide's settled final state, every step
revealed, so what you see in the sidebar is what the slide says when you are
done with it.

Jumps land on held states, like all backward movement: content settled,
ambient motion running, no replayed entrances. Forward from wherever you
landed animates as authored.

## Where to next

- [Performance and previews](../advanced/performance-and-previews.md): when
  previews render and what they cost.
- [Keyboard and remotes](../getting-started/keyboard-and-remotes.md): the
  rest of the key map.
