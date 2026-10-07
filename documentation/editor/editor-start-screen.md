# The start screen

The slides app opens on the start screen. It has one job: get you into a
deck. Two buttons do most of the work, your recent decks sit next to them,
and everything else is one click away.

## The two primary actions

- **New deck** opens the editor on one empty slide. The deck is called
  `untitled.fluvie` until you save it.
- **Open a deck** opens a `.fluvie` file from your machine in the editor.

Both live in the left column under **START**, on top of everything else, so
they never scroll away.

## The secondary actions

Under **MORE**:

- **New from template** opens the template gallery: a pitch, a report, a
  portfolio, and a master starter, each with its own theme and masters.
- **Present a .fluvie file** plays a deck without opening the editor. Use it
  when you only need to show a deck someone sent you.
- **Samples and tutorials** opens the sample browser. See below.

You can also drop a `.fluvie` file anywhere on the window to present it.

## Recent decks

Every deck you open, save, or rename lands in the recents list, newest
first, capped at eight. A tap reopens it in the editor. Each row shows when
you last opened it and where it lives.

In the browser there are no file paths, so a web entry shows as history
instead of a button. Reopen it with **Open a deck**.

The list is stored in `~/.config/fluvie_slides/recent_decks.json` on desktop
and under the `fluvie_recent_decks` localStorage key on the web. Delete
either one to clear the list.

## Templates

The template strip shows one card per built-in template with a small sketch
of the theme it ships. A card starts a new deck from that template right
away. **Browse all** opens the same gallery the **New from template** tile
opens, grouped by purpose.

See [Themes, masters, and templates](editor-themes.md) for what a template
carries.

## Samples and tutorials

The seven bundled example decks live behind **Samples and tutorials**. Each
one presents, and each one teaches the feature it uses:

| Deck | What it shows |
| --- | --- |
| Plain slides | One scene is one slide |
| Builds with Stop | Reveal content step by step |
| Speaker notes | Scene defaults and per-step overrides |
| Media-heavy slides | Charts, code, and live elements |
| Embedded video | Real players with sound, on the web |
| What is fluvie | Fourteen slides, notes on every one |
| The full talk | Everything together, end to end |

The same dialog holds **Edit the demo deck**, which opens the bundled demo
spec on the canvas instead of presenting it.

## The first-run tips

On your first run the screen shows a **New here?** card with four things
worth knowing: scenes are slides, the presenter keys, the render path, and
where the samples are. It disappears when you dismiss it or once you have a
recent deck.

To bring it back, delete
`~/.config/fluvie_slides/start_prefs.json` on desktop, or the
`fluvie_slides_start_prefs` key in the browser's localStorage.

## Where to next

- [Editor getting started](editor-getting-started.md): the tour of the
  editor itself.
- [Themes, masters, and templates](editor-themes.md): what a template
  brings with it.
- [FAQ](editor-faq.md): short answers to the questions the editor raises.
