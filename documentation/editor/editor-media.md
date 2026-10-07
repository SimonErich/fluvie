# Media and bundles

Drop a photo or a clip into the editor and it becomes part of your deck.
This page covers the three ways media comes in, where the bytes live on
each platform, and how a deck travels with its media.

## Importing media

Media enters the editor three ways:

- The media tool (M) opens the system picker for images, videos, and audio
  files.
- Dropping a file onto the canvas inserts it on the current slide.
- The Assets dialog (in the toolbar) lists everything the deck already
  holds, one tap to reuse it.

An image inserts as an `Image` element, a video as a `Clip`, both centered
on the slide. An audio file joins the deck's media store only; the video
mode's audio tracks pick it up from there.

## The media store

Every import is recorded in the document's `editor.media` block: the file's
name, its kind, its source, and its size. The store feeds the Assets
dialog, so a file you imported once is one tap away on every slide. Remove
an entry with the trash control next to it. Store entries are editor
metadata: they never change how the deck renders, and the render digest
ignores them.

## Where the bytes live

On desktop an import stays a file path. The document references
`{"kind": "file", "value": "/path/to/photo.png"}` and the render pipeline
reads it from disk, exactly as before.

Saving makes those paths portable. Any image or video file inside the
document's own folder is written relative to it, as
`{"kind": "file", "value": "media/photo.png"}`, so the folder travels as
one unit: move it, reopen the deck, and the values resolve against the
file's new location. Paths outside the folder stay absolute, and audio
paths always stay absolute (the spec requires it). The values stay
relative inside the saved JSON, so the render digest is stable from one
machine to the next.

The web has no file paths. An imported file's bytes stay in the session:
the document references them with a bundle source,
`{"kind": "bundle", "value": "media/photo.png"}`, and the live preview
resolves that reference against the session's bytes. The session bounds its
total size; an import past the budget is refused with a visible message
instead of a silent drop.

## Saving a deck with session media

Session bytes cannot live inside a JSON file. When you save a deck that
references them, the editor asks:

- **Save bundle** writes one `.fluvie` file that is a zip: the deck JSON
  plus a `media/` folder with every referenced file. The deck travels with
  its media.
- **Save JSON only** writes the plain document. The media references stay
  in the text, but the bytes do not travel.
- Check **Don't ask again for this deck** and your choice is remembered in
  the document; Save stops asking.

Both forms use the one `.fluvie` extension. Opening sniffs the first bytes:
a zip is unpacked (only `media/` entries, size-capped, traversal names
refused) and its media is restored into the session; anything else parses
as plain JSON. Reopening a bundle and saving it again produces the same
document, byte-identical media included.

Save a copy always writes plain JSON, so it warns first when the deck
references session media.

## Crash recovery and session media

Autosave covers session media too. On desktop, an autosave of a deck that
references session bytes is written as a bundle sidecar (the same zip form
a `.fluvie` bundle uses), so recovery after a crash restores the document,
the bytes, and the previews in one step, even for a deck you never saved.

The web's localStorage cannot hold media bytes, so a web autosave keeps the
document JSON alone. Recovery is still complete in the common case: reopen
your bundle file and its media repopulates the session, and the autosaved
edits recover over it. Only media imported after your last bundle save has
no surviving bytes; a recovery that would break such references stops and
names them instead of opening a broken deck, and keeps the autosave for an
open that has the media.

## Presenting with a speaker window

The web speaker popup is its own browser window, so your session's bytes
are not in it. Presenting hands the popup a session-scoped copy of the deck
whose bundle references are rewritten to object URLs minted in the main
window; the popup fetches the same bytes through them for as long as the
main window stays open. Nothing of this is saved: your document keeps its
bundle references, and the rewritten copy dies with the session. If you
open the speaker route later, without a presenting main window, its media
URLs are gone with the window that minted them.

## Where to next

- [Editor getting started](editor-getting-started.md): the tools and
  panels around the canvas.
- [The canvas](editor-canvas.md): placing and arranging what you import.
- [The timeline](editor-timeline.md): animating the media once it is
  placed.
