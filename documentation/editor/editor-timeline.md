# The timeline

The timeline panel sits under the canvas and shows when the current slide's
motion happens. One track per element, in layer order; one bar per
animation, colored by phase: enter, during, exit. The panel opens by
default; its header collapses it.

## Bars: retime and trim

Drag a bar to retime its animation: the drag writes the animation's delay,
so it works the same for every trigger form. Drag an edge to trim the
duration; the left edge moves the start too. One drag is one undo step. A
slide with no animations shows a one-line offer to add a first `fadeIn`.

## Keyframes: the diamonds

A `keyframes` animation draws a diamond per stop. Click a track at the
playhead to insert a stop there, interpolated between its neighbors. Drag a
diamond to move its stop; stops never cross. Delete removes the selected
stop, and a two-stop bar loses the whole animation, because one stop is not
a keyframe animation. Trimming a bar rescales authored stop positions
proportionally.

Select a diamond and the inspector grows a Keyframe section with the stop's
full field set: position, scale, rotation, opacity, color, origin, and the
easing of the outgoing segment.

## The Animate panel

The inspector's Animate section lists the selected element's animations
from the same model the timeline draws, so the two can never disagree. Each
row edits duration, ease, trigger, and offset, and removes. Add opens a
searchable picker of every preset, grouped by phase. Triggers cover the
keyword forms (auto, previous, scene start, scene end) and the anchor forms
("when X ends", "when X starts"); anything authored beyond that shows as a
read-only custom trigger rather than being flattened.

## Trigger links

A bar with a cross-element trigger draws an elbow connector from its
trigger's bar, labeled with the offset (`+12f`). Drag the small handle at a
bar's top onto another bar to create a link: the editor mints the anchor
and writes the trigger in one undo step. Re-drop to retarget, or delete the
link to return the animation to automatic timing. A drop that would create
a timing cycle is refused before it can break the deck.

## Build markers: click steps

Markers on the ruler split the slide into presenter click steps, in exact
parity with the presenter's own step compiler: marker k sits where step k
settles. Double-tap the ruler to split a step, drag a marker to re-balance
two steps, drag it off the ruler (or press Delete) to merge. When a step
plan is invalid, the panel header names the problem and the offending bars
outline in the error color.

## Scrub and transport

The ruler's playhead is the one clock: the canvas, the ruler, and the
readout always agree on the frame. Scrub to seek; the stage holds the exact
frame. The header plays and pauses, and Shift-drag on the ruler arms a
loop over a range (Escape clears it).

Space is contextual. With the panel open it toggles playback. With the
panel closed it steps the slide the way a presenter click would, landing on
each build step's settled state, and walks into the next slide past the
last step.

## The notes strip

Under the timeline sits the speaker-notes strip: prose plus highlight
bullets per slide, with per-step scopes when the slide has build markers.
What you type here is exactly what the speaker window shows. Step text
replaces the slide text; step highlights append.

## Where to next

- [Configure a TrackTimeline](../reference/track-timeline.md): migrate the
  grouped widget inputs when you embed a timeline.
- [The canvas](editor-canvas.md): the space those bars animate in.
- [Timing and triggers](../guides/timing-and-triggers.md): the timing model
  the timeline edits.
- [Animating elements](../guides/animating-elements.md): the presets behind
  the Animate panel.
