# Video mode

Flip the editor into a video editor: the whole composition on one absolute
clock, clips and audio as lanes, and a real MP4 out the other end. Same
document, same undo history, same canvas. Video mode is a different lens
over time, not a different file.

## Switching modes

The top bar carries two mode buttons: Slides and Video. The switch is one
undoable step, and the document remembers its mode across saves. Nothing
drops on a switch: steps, notes, and per-slide animation have no video-mode
surface, but they stay exactly as authored and come back with Slides mode.
A deck that never enters video mode never writes the mode key.

## Importing media

Import works the same in both modes: the file picker (press M), drop onto
the canvas in slides mode, or the assets panel for reuse. A video import
lands as a clip on the canvas and an entry in the deck's media store. An
audio import is store-only: audio has no canvas shape, so it waits in the
store until you add it as a track. On the desktop an import keeps its file
path; on the web the bytes live in the session, and Save offers a `.fluvie`
bundle so the deck travels with its media.

## The timeline lanes

Video mode's panel shows the whole video: scene blocks on a ruler, one lane
per clip (and per element with an authored time window), and one lane per
audio track.

- Drag a clip lane to move it in time. The drag writes the element's `show`
  window; the video's edges are the only hard walls.
- Drag the bar's start into another scene and the element moves there. It
  lands exactly where you dropped it, keeps its transform, props, and
  animations, and comes out on top of the target slide's stack. If the old
  slide's build steps named it, the move strips it from them and the panel
  header says so. A group moves whole; a grouped element never moves alone.
- Drag a lane edge to trim. Trimming a full-scene clip mints its first
  window.
- A music bed refuses to move, because the spec has no key for a delayed
  bed; it starts with its owner. Trim it instead. The panel header says
  exactly that when you try.
- A sound effect moves by rewriting its start time. If a trigger places it,
  the drag is refused rather than silently destroying the trigger.

Every lane edit is one undo step, and a refused or clamped drag explains
itself in the panel header.

## Lanes

A deck can declare lanes, and the timeline draws one row for each of them in
declaration order. Clips and audio tracks that name a lane sit on its row;
anything that names none keeps a row of its own, exactly as it did before
lanes existed. A declared lane with nothing on it is still a row, because that
is where you drag the next clip.

Drag a clip onto another lane's row and it moves there. Its window, its trim
and its place in the stack are untouched: a lane says where a clip is *shown*,
never what order it paints in, so re-laning never changes the picture. The move
and the re-lane are one drag and one undo step.

A muted lane is silent, in the preview and in the export. That is the one lane
setting the renderer reads.

## Reading the lanes

The ruler carries timecode and seconds together: an author laying out a
forty-second video thinks in seconds, and one matching a cut to a reference
reads the timecode.

A lane can set its own height, and an audio lane uses the room for its
waveform, drawn from the decoded envelope across the whole lane. A clip lane
can carry a filmstrip; the frames are asked for only as they scroll into view,
because decoding a whole project to draw a strip nobody looked at is the one
cost a timeline cannot afford.

Only the rows the panel can actually show are built and painted, so a project
with a hundred lanes scrolls like one with five.

## Effect rows and their diamonds

An element with an `effects` stack grows one row per effect, indented under
its bar. The effect's bar spans the element's window, because an effect has
no span of its own: it runs for its element's life. When the element sits on
a declared lane, the effect row carries the element's name too, so you always
know whose grain you are looking at.

A keyframed parameter draws a diamond per stop, the same diamonds slides mode
draws for `keyframes` animations:

- Park the playhead inside the bar and click the effect's row to add a stop
  there. The new stop takes the value the ramp already reads at that frame,
  so the picture at that frame does not change. On an eased segment the two
  halves re-ease from the new stop, which reshapes the curve around it, the
  same way an animation keyframe insert does.
- Drag a diamond to move its stop. It stays strictly between its neighbors,
  and the whole drag is one undo step.
- Click a diamond and press Delete to remove its stop. At the two-stop
  minimum the parameter collapses back to a literal, the surviving stop's
  value, because a one-stop ramp is a plain number wearing a list.

A still parameter never grows stops from the timeline. Converting a literal
into a keyframed value is the Effects tab's job.

## Selecting clips

Click a bar to select it. Shift or Ctrl adds one to the selection, and a drag
across empty lane space draws a rubber band that takes every bar it touches,
across as many lanes as it crosses. A band that catches nothing clears the
selection, which is what sweeping empty space plainly means.

Selecting a bar also selects its element on the canvas, so the inspector
follows. The two selections stay separate underneath: a bar is a span of time
on a lane and an element is a thing on the canvas, and a verb aimed at one
must never find the other.

## The razor

Park the playhead inside a selected clip and press `B` (or use the scissors in
the panel header) to cut it in two. Every selected clip the playhead sits
inside is cut, in one undo step, and the ones it misses are left alone.

The halves play exactly what the clip played. The head keeps the clip's
identity, its place in the stack and everything it carried; the tail is a new
element with the same props and a trim that picks up where the head left off,
so the cut does not restart the footage. A reversed clip cuts from the far end,
because that is the end it plays from.

Two cuts it refuses, and says so rather than guessing:

- A clip inside a group. Ungroup it first, or the halves would land outside
  the group.
- A clip whose trim is written in source frames. Source frames only mean
  something at the source's own frame rate, which the editor cannot read;
  rewrite the trim in seconds and the cut is exact.

## Ripple, roll, slip and slide

Each of these is defined by what it holds still, and each is one gesture with
one modifier held.

| Gesture | Does | Holds still |
| --- | --- | --- |
| Drag a bar | Moves the clip | Everything else |
| Alt + drag a bar | Slips: changes what plays | When it plays |
| Shift + drag a bar | Slides: changes when it plays | What it plays, and its neighbours' outer edges |
| Drag an edge | Trims | Everything else |
| Alt + drag an edge | Ripple trims: what follows moves with it | The clips before it |
| Shift + drag an edge | Rolls the cut | Both clips' outer edges |

`Shift+Del` ripple deletes the selected clips: they go, and what followed them
on the same slide comes back to fill the gap.

A ripple never changes a slide's length, because a window is measured inside
its slide. Where nothing follows the gap, it stays and the header says why. A
clip that overlaps a deleted span is left where it is rather than pulled
somewhere the author never put it, and the header names how many.

Every one of these is one undo step, and every refusal or clamp explains
itself in the panel header: a roll with no cut to move, a slide with no
neighbour to absorb it, a slip already at the start of its source.

## Snapping

Drags catch on the frames that matter: the playhead, every scene boundary,
and every other bar's start and end. A white guide line flashes where the
catch happened, so a bar that lands on a cut looks like it meant to.

- A moved bar catches on either of its own edges. Drag a clip so its tail
  meets the next scene and the bar lands with the tail exactly on the cut.
- A trimmed edge catches on its own, and the edge you are not dragging never
  moves.
- Hold Ctrl while dragging to bypass the catch for that one drag.
- Turn snapping off entirely in the canvas aids; the timeline reads the same
  switch, so the two can never disagree.

The catch is eight pixels wide whatever the zoom, so it feels the same
distance away when a whole minute is on screen and when ten frames are.

## Audio tracks and the inspector

The header's Add audio picker lists the store's audio entries and appends
one as a video-level music track. Tap an audio lane to open the audio
inspector on the right: volume, fade in, fade out, loop, trim, and, for a
sound effect, its start. Tracks reorder and remove there too. Multiple
tracks layer and mix through the same `amix` graph a hand-written Fluvie
composition uses.

## Scrubbing

One clock drives everything. The playhead crosses scene boundaries, the
canvas shows the exact frame, and Space always toggles playback. The
slide stepper seeks scene starts on the same clock, and interactive
editing targets the scene under the playhead, exactly like slides mode on
that slide.

## Export to MP4

Export lives in the top bar's Export menu, in both modes.

- **Desktop**: the deck renders through fluvie's capture loop and your
  local FFmpeg, into a file you pick. The progress dialog follows the
  capture and encode phases.
- **Web**: the deck renders fully in the browser through ffmpeg.wasm, with
  audio enabled, and lands as a download. The page must ship the
  `FluvieFfmpeg` bridge in `index.html` (vendor the wasm files with
  `apps/slides/tool/fetch_ffmpeg.sh`). Without the bridge the menu entry stays visible
  but disabled and names what is missing; there is never a dead button.
  ffmpeg.wasm is much slower than native FFmpeg, so long renders belong on
  the desktop.

Both paths feed the same spec-built `Video`, so the mix you authored in the
lanes is the mix in the file: every track's volume, fades, trim, and start
become the same FFmpeg filter graph on either platform.

The same menu also exports still forms of the deck: numbered PNGs, or one
PDF with a page per slide at the deck's canvas size, both rendered from
each slide's settled final state.

## Where to next

- [The Effects tab](editor-effects.md): stack, tune and keyframe the
  effects whose rows and diamonds you see here.
- [Media and bundles](editor-media.md): where imported bytes live and how
  a deck travels with them.
- [The timeline](editor-timeline.md): the slides-mode lens on time, per
  slide and per element.
- [Audio and captions](../guides/audio-and-captions.md): the `Audio` model
  the lanes and inspector edit.
