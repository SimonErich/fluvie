# Editor FAQ

Short answers to the questions the editor raises.

## Why is my element not animating?

An element only moves if it carries an animation. Select it and check the
inspector's Animate section: an empty list means a still element. Add a
preset there, or check the timeline for its bar. Two more traps: a hidden
element (`visible: false`) builds nothing, so it has no timeline bars at
all; and in Present mode entrances play once when the slide appears, so
scrub back in the editor's timeline to watch them again.

## What does the saved indicator actually compare?

The document's digest, a fingerprint of the whole JSON. `Saved` means the
current digest equals the digest of what is on disk, so undoing your way
back to the saved state reads `Saved` again without saving. `Autosaved just
now` means the crash-recovery copy covers your current state; the file on
disk is still behind until you save.

## Where does autosave live?

On desktop, under your user config directory:
`~/.config/fluvie_slides/autosave/`. On the web, in the browser's
localStorage. One record per deck, holding exactly what Save would write —
and on desktop, a deck referencing imported session media autosaves as a
bundle sidecar, bytes included, so a crash loses nothing. Opening a deck
that has a newer autosave prompts you to recover; the file on disk stays
untouched until you choose to save. On the web the record alone survives:
reopen your bundle first and recovery has its media; the prompt names any
media it cannot rebuild instead of opening a broken deck.

## How do I bring the intro tips back?

The start screen shows the "New here?" card until you dismiss it or save
your first deck. Delete the file that remembers the dismissal and it
returns: `~/.config/fluvie_slides/start_prefs.json` on desktop, or the
`fluvie_slides_start_prefs` key in the browser's localStorage on the web.
The same file holds your recents neighbour, `recent_decks.json`, which you
can delete to clear the recent list.

## What is different on the web?

Everything edits and presents the same. Saving uses the File System Access
API where the browser has it, and falls back to downloads. Export slide
images downloads numbered PNGs instead of asking for a folder, and Export
PDF downloads the one file (the PDF bytes build the same everywhere).
Export video renders fully in the browser through ffmpeg.wasm and lands as a
download; the page must ship the `FluvieFfmpeg` bridge in `index.html`
(vendor the wasm files with `apps/slides/tool/fetch_ffmpeg.sh`). Without
the bridge the entry stays visible but disabled and names what is
missing. ffmpeg.wasm is much slower than native FFmpeg, so long renders
belong on the desktop.

## Why did pasting change my element's ids?

Every paste and duplicate mints fresh ids, so two elements can never share
one. References inside the copied set follow the re-mint; your other
elements keep theirs.

## Do blocks or groups change how my deck renders elsewhere?

No. A block is editor bookkeeping over a real `Group` whose children carry
ordinary transforms. Open the deck in any Fluvie renderer, or clear the
block, and the layout is pixel-identical.

## Why does auto-animate skip one of my elements?

It pairs elements that are the same content on both slides, or that share
an explicit id. An element with no partner is skipped on purpose: the
engine never invents motion, so unmatched elements ride the slide's
authored transition. Use the Morph row on the element to link a pair by
hand.

## The exported Dart source lost my build steps and notes?

It cannot express them: plain fluvie code plays straight through. The
printed file says so in a leading comment. Present from the `.fluvie` file
(or `deckFromSpec`) and steps and notes are preserved; the Dart export is
for rendering and for reading your deck as code.

## Is there a keyboard shortcut for undo?

Yes: Ctrl/Cmd+Z undoes and Ctrl/Cmd+Shift+Z (or Ctrl+Y) redoes, anywhere
in the editor; the top bar's two arrow buttons do the same. Every command
is one undo step, including a whole drag or a whole theme apply.

## Where did my second monitor's speaker notes come from?

From the notes strip under the timeline. Slide-scope notes show on every
step; a step scope replaces the text and appends its highlights, exactly
as the strip's preview line shows.

## Where to next

- [Editor getting started](editor-getting-started.md): the tour.
- [The start screen](editor-start-screen.md): recents, templates, samples.
- [Editor shortcuts](editor-shortcuts.md): the full key map.
- [Authoring with specs](../guides/authoring-with-specs.md): the same
  document, written by hand or by a model.
