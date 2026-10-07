# Editor shortcuts

Everything the editor listens for. On macOS, Cmd replaces Ctrl in every
chord. The Edit and Arrange tables are the command registry's own bindings;
menus and the command palette print the same chords, and a test pins this
page to the registry, so the table cannot drift.

## Tools

| Key | Does |
| --- | --- |
| `V` | Select tool |
| `H` | Hand tool (pan) |
| `T` | Text tool |
| `R` | Rectangle |
| `O` | Ellipse |
| `L` | Line |
| `A` | Arrow |
| `M` | Insert media |
| Esc | Cancel the drag, else back to select, else exit the group, else clear the selection |

## Edit

| Chord | Does |
| --- | --- |
| `Ctrl+Z` | Undo |
| `Ctrl+Shift+Z` (or `Ctrl+Y`) | Redo |
| `Ctrl+X` | Cut |
| `Ctrl+C` | Copy |
| `Ctrl+V` | Paste |
| `Ctrl+D` | Duplicate |
| `Ctrl+A` | Select all |
| `Del` (or Backspace) | Delete |

Paste re-mints element ids, so a copy never collides with its source, and
nudges the copy when it lands on the same slide.

## Arrange

| Chord | Does |
| --- | --- |
| `]` | Bring forward |
| `[` | Send backward |
| `Ctrl+]` | Bring to front |
| `Ctrl+[` | Send to back |
| `Ctrl+G` | Group |
| `Ctrl+Shift+G` | Ungroup |
| `Ctrl+Shift+L` | Lock |
| `Ctrl+Shift+H` | Hide |

## On the canvas

| Input | Does |
| --- | --- |
| Arrows | Nudge the selection one canvas pixel |
| Shift+Arrows | Nudge ten pixels |
| Ctrl (held while dragging) | Bypass snapping, on the canvas and the timeline |
| Shift (while resizing) | Keep the aspect ratio |
| Alt (while resizing) | Resize from the center |
| Shift (while marqueeing or clicking) | Add to the selection |
| Double-click | Enter a group, or edit a text inline |
| Right-click | The context menu for whatever is under the pointer |

## Timeline and transport

| Input | Does |
| --- | --- |
| Space (panel open) | Play or pause |
| Space (panel closed) | Step to the next build landing; past the last, the next slide |
| Shift-drag the ruler | Arm a playback loop over the range |
| Esc | Clear the loop |
| Del | Remove the selected keyframe or build marker |
| Double-tap the ruler | Split a build step |

## Timeline

The verbs that act on time rather than on the canvas. None of them is an edit,
so none of them lands on the undo stack — moving the playhead is navigation,
and burying your real steps under it would make undo useless.

| Input | Does |
| --- | --- |
| `I` | Mark in, at the playhead |
| `O` | Mark out, at the playhead |
| `Shift+I` | Go to in |
| `Shift+O` | Go to out |
| `Page Up` | Previous edit |
| `Page Down` | Next edit |
| `B` | Razor at playhead |
| `Shift+B` | Razor all lanes |
| `X` | Lift selection or marked range |
| `Shift+X` | Extract marked range |
| `Shift+S` | Timeline snapping |
| `Shift+N` | Add lane |
| `Shift+Del` | Ripple delete |

Next and previous edit land on the frames where the picture actually changes:
each scene's start and end, and the frame it settles on after its incoming
transition. They read the same timebase the compositor mounts against, so they
cannot land somewhere nothing happens.

The page keys carry these rather than the arrows, because the arrows nudge the
selected element on the canvas and the registry dispatches by key across every
surface.

The razor and the ripple delete are the two edits here, and the only verbs on
this page that land on the undo stack.
It cuts every selected clip the playhead sits inside, as one step, and leaves
the ones it misses alone. The halves play exactly what the clip played: the
tail picks up the source where the head left off rather than restarting it.

The other six need a playhead to act on. A stage holding a settled still (slides
mode, and master editing) has none, so they read as disabled there rather than
marking frame zero, which is a real position and not an absence.

## Everything else

| Input | Does |
| --- | --- |
| `Ctrl+K` | The command palette |

Undo and redo also sit on the top bar as the two arrow buttons. In Present
mode the presenter's own keys apply: arrows and Space step, `F` is
fullscreen, `B` blacks the screen, `S` opens the speaker window.

## Where to next

- [The canvas](editor-canvas.md): the tools behind the letters.
- [The timeline](editor-timeline.md): what Space steps through.
- [FAQ](editor-faq.md): the questions the key map raises.
