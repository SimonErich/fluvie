# The Effects tab

Stack visual effects on any element and tune them without leaving the
editor. The tab edits the same `effects` list the spec carries, so what you
build here renders identically from the document, from generated Dart, and
in the export.

## Add an effect

Select an element and open the **Effects** tab in the inspector column. Add
an effect three ways, and all three land the same command:

- Pick it from the searchable **Add effect** select.
- Click a chip in the grouped browser under it. Hover a chip to read what
  the effect does.
- Drag a chip onto the element on the canvas, or onto a bar in the video
  timeline. The effect lands on the element under the pointer.

Thirteen effects ship: grade, curves, lut, grain, vignette, scanlines,
chromatic, bloom, blur, glitch, particles, shader and parallax. Each arrives on its own defaults, so
a freshly added effect renders exactly what a bare `{"kind": ...}`
declaration would. A bare grade is the identity: it changes nothing until
you move a slider.

## Edit the stack

Each effect is a tile in stack order. Drag tiles to reorder; order matters,
because the stack composes by class then list order. The switch turns an
effect off without losing its settings, exactly as `visible: false` works
for an element: off stays in the document. The trash removes it. Add,
reorder, toggle and remove are one undo step each.

Numeric parameters are scrub fields: drag the label to scrub, type math to
commit, arrow keys to step. Each field clamps to the effect's honest range,
and each committed value is its own undo step, like every scrub field in
the inspector. Boolean and choice parameters use a switch and a select.

Blur exposes sigma in logical pixels; zero is an exact no-op. Glitch intensity
scales its band displacement and channel split while preserving the original
animation's timing and default appearance. The curves editor exposes actual
channel control points. Particle settings and shader uniforms have validated
JSON editors with explicit Apply actions; invalid drafts remain visible for
correction and do not change the document.

See [Colour](editor-colour.md) for Looks, portable LUT import, white balance and
scopes.

## The diamond

Every numeric row ends in a diamond. Click it to keyframe the parameter: the
literal becomes a flat two-stop ramp over the element's own window, so the
picture does not change and the stops appear as diamonds on the element's
effect row in the video timeline. From there, edit the ramp on the timeline:
add stops at the playhead, drag them, delete them.

Click the diamond again to collapse the ramp back to a single value: the one
it reads at the playhead, so what you see is what you keep.

## Copy a look

**Copy Effects** puts the selected element's whole stack on the clipboard;
**Paste Effects** appends it to every selected element as one undo step. The
clipboard carries plain JSON text, so a look travels between documents and
between editor windows. Both verbs live in the element's right-click menu
and the command palette.

## Where to next

- [Video mode](editor-video-mode.md): the effect rows and their diamonds on
  the timeline.
- [Authoring with specs](../guides/authoring-with-specs.md): the `effects`
  list and keyframed parameters in the document itself.
- [The timeline](editor-timeline.md): the slides-mode lens on time, per
  slide and per element.
