# Continuity across slides

A slide is a chapter marker, not a wall. Three things cross one: an overlay
runs the whole video as a single element, a shared chain morphs a hero through
every cut it touches, and a boundary is a hairline you can drag.

## Overlays: one element for the whole video

An overlay lives outside every slide. It is mounted once, never re-parented at
a boundary, and its window is measured against the whole video rather than a
slide — so it holds through every cut and every blend without blinking.

Use one for anything that belongs to the video rather than to a moment: a
logo, a lower third that runs a whole section, a watermark, a progress bar.

- The timeline draws an overlay as **one bar spanning its window**, crossing
  boundaries with no seam. There is no slide to clamp it to.
- Adding one never lengthens the video and never moves a boundary.
- Overlays paint above every slide, in declaration order, and below captions.
- An overlay cannot be a shared hero: it already runs the whole video, so
  there is no boundary for it to morph across.

An overlay is drawn on one slide's canvas — its **home** — so you can place it,
size it and style it the way you place anything else. The home is editorial: it
decides where you edit the overlay, never when it plays, and it never moves the
render digest. Deleting its home slide re-homes it rather than deleting it,
because it belongs to the video and not to that slide.

**Make global** turns a slide element into an overlay and **Make slide-local**
turns one back, each in one undo step. Neither moves the bar a pixel: a
slide-relative window and an absolute one are two ways of naming the same
frames. Coming back into a slide, a window that reaches past that slide is
clamped to it — there is no honest way for a slide-local element to outlive its
slide.

## Shared chains: a hero that morphs through the cuts

Two elements naming the same `shared` id in neighbouring slides are one
logical thing: during the blend, the editor draws it travelling from the first
rect to the second. That is a **morph** — two elements made to look like one.

A chain is any contiguous run of slides, not just a pair. A hero declared in
slides 1, 2 and 3 morphs through both cuts, each boundary blending its own two
ends. What a chain may not be:

- **One slide.** A hero with nothing to morph to.
- **A run with a gap.** The hero would vanish for a slide and come back, which
  is two morphs pretending to be one.

Both are refused with the anchor named, rather than rendering something
nobody meant.

**Morph or overlay?** A morph is the right answer when the thing genuinely
changes across the cut: a title that starts large and centred and ends small
in a corner. An overlay is the right answer when it does not change at all.
If you find yourself giving both ends identical geometry, you wanted an
overlay.

The timeline shows a chain as one bar. Its first and last edges span the
member scenes; dragging an edge applies the same local-frame timing change to
every member and clamps at each scene's bounds. A chain keeps its scene
memberships. Razor divides the logical bar into left and right chains, including
a cut exactly on a scene boundary. Lift removes the selected chain or marked
range; Extract and Ripple delete close its gaps within each member scene. Each
operation is one undo step and retains every member’s authored geometry.

Inspector content edits propagate the changed properties through the chain in
one undo step. Unchanged properties keep their authored values. Geometry,
anchors and identity remain local, so moving the title in one scene retains the
other scenes' poses.

## The hairline and the bar edge

Two lines on the timeline, two different gestures:

| Line | What it is | Dragging it |
| --- | --- | --- |
| A **hairline** on the ruler | A slide boundary | Retimes the slide before it |
| A **bar edge** on a lane | A clip's in or out point | Trims that clip |

They look different because they mean different things. A slide's length is
the master clock: retiming one moves every slide after it and changes the
video's length. Trimming a clip changes only that clip.

The same retime is a number in the inspector, under **Length**: frames and
seconds, one gesture apart from the drag, writing exactly the same command.

Two things a retime is honest about:

- A slide too short to hold its own transitions is refused, in the engine's
  own words, rather than written into a document that would fail to render.
- Windows that no longer fit are clamped into the shorter slide, and the note
  names them. A window that starts past the new end loses its timing rather
  than being written inverted: the element keeps its place on the canvas.

## Where to next

- [Video mode](editor-video-mode.md): lanes, the razor, and the trim family.
- [The timeline](editor-timeline.md): the slides-mode lens on time.
- [Scenes and transitions](../guides/scenes-and-transitions.md): the blends a
  chain morphs across.
