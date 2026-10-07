# Exporting a video from the editor

`Export > Export video (MP4)` opens the options dialog, then renders the open
deck through your platform's pipeline: a local FFmpeg on the desktop, or
ffmpeg.wasm in the browser when the page ships the bridge.

The dialog opens on the deck's own settings, so confirming it unchanged means
"export exactly what I authored".

## Resolution

Pick a canvas size. The list starts at the deck's own long edge and offers
smaller rungs below it.

Only the size scales; the deck keeps its aspect. A 16:9 deck exported at 720
renders 720 x 405, and a 9:16 deck exported at 720 renders 405 x 720. The label
under the picker shows the canvas you will get.

Larger sizes than the deck are deliberately not offered. Re-rendering above the
authored canvas draws vector content sharper, but it cannot invent detail in a
video clip or an imported image, so the option would promise more than the
render delivers. Author at the size you want to deliver.

## Quality

Quality maps to the encoder's rate factor. `high` is the default and is what
every render used before this dialog existed, so an unchanged export is
byte-for-byte the render you had.

Lower quality means a smaller file, not a smaller canvas — the resolution
picker is the one that changes pixels.

## Frame rate

Frame rate is different from the other two, and the dialog says so when you
change it: **it edits the deck.**

A deck's timeline is measured in its own frames. Every scene duration, every
`show` window and every animation span resolves against the deck's rate. So
there is no honest way to capture a 30 fps deck at 60: the render would pump
frames the composition's timeline does not have, and the video would either run
past the end holding its last frame or stop short.

Changing the rate therefore rewrites the document before the render starts. It
is an ordinary edit: it lands on the undo stack and marks the deck unsaved, like
any other change.

## What happens next

The progress dialog reports the phases the pipeline reports — capturing frames,
then encoding — and ends with the written path. A cancelled save dialog closes
it quietly. A failed render leaves the reason in the dialog rather than
discarding it.

On a web page without the ffmpeg.wasm bridge the menu entry stays visible and
disabled, naming what is missing, instead of quietly disappearing.

## Where to next

- [The canvas](editor-canvas.md) — authoring the deck you are exporting.
- [Video mode](editor-video-mode.md) — arranging clips on the timeline.
- [Exporting your video](../guides/exporting-your-video.md) — the same pipeline
  from Dart, with the export modes the dialog does not yet offer.
