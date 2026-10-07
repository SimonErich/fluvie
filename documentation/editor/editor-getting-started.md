# The editor: getting started

The Fluvie editor is a visual presentation editor. Your document is a
`.fluvie` file, the same JSON spec the rest of Fluvie reads, so a deck you
draw on the canvas renders as a video, presents live, and loads from code.

Open the slides app and you are looking at the start screen:

- **New deck** starts from one empty slide.
- **Open a deck** opens a `.fluvie` file you already have.
- **New from template** opens a gallery of complete starter decks.
- **Present a .fluvie file** plays a deck without opening the editor.
- **Samples and tutorials** holds the seven bundled example decks and
  **Edit the demo deck**, which opens the bundled example on the canvas.

See [The start screen](editor-start-screen.md) for the rest of it.

The app runs in the browser at [slides.fluvie.dev](https://slides.fluvie.dev)
or as a desktop build from `apps/slides` in the repository. Everything below
works in both; the differences are listed at the end.

## Put something on a slide

Pick a tool from the left toolbar, or press its key:

- `T` drops a text element. Type straight into it.
- `R` draws a rectangle, `O` an ellipse, `L` a line, `A` an arrow.
- `M` inserts an image or video from a file.
- `V` returns to the select tool. So does Escape, and so does finishing a
  placement.

Every element lands with a real position and size in the document. Drag to
move it, drag a handle to resize, use the top handle to rotate. The
inspector on the right edits the numbers directly.

## Style it

Select an element and the inspector shows its content, transform, and
style. Color fields open a picker that leads with your theme palette; tap a
token to bind the color to the theme, so a theme switch restyles the deck.
The Theme tab on the left edits the palette, type scale, spacing, and
motion. See [Themes, masters, and templates](editor-themes.md).

## Save

Save writes the document as pretty-printed `.fluvie` JSON. The first Save
asks where; after that it rewrites the same file silently. The quiet label
next to the deck name tells you where you stand: `Saved`, `Unsaved`,
`Autosaved just now`, or `Saving…`. Autosave covers you between saves; if
the app dies, the next open offers to recover.

The document is plain spec JSON:

```json
{
  "fluvieSpec": 1,
  "size": { "width": 1920, "height": 1080 },
  "fps": 30,
  "scenes": [
    {
      "duration": "6s",
      "children": [
        {
          "id": "el-1",
          "type": "Text",
          "text": "Hello",
          "transform": { "x": 0.5, "y": 0.3, "w": 0.8, "h": 0.2 }
        }
      ]
    }
  ]
}
```

Anything Fluvie can read can open this file. Nothing the editor writes is
editor-only magic; its own bookkeeping lives under one `editor` key that
renderers ignore.

## Present

Present plays the deck live over the editor, stepping like a presenter:
entrances play, then the slide waits for you. Close it and you are back on
the canvas with every edit intact. Build steps and speaker notes authored
in the timeline and notes strip carry into the speaker window.

## Export

The Export menu in the top bar offers five ways out:

- **Export .fluvie** saves the document to a fresh file (Save as).
- **Export Dart source** writes a runnable `Video build()` Dart file,
  printed by the fluvie_cli printer. Theme tokens print as resolved
  literals and masters print applied, so the code renders exactly what you
  see.
- **Export slide images (PNG)** renders every slide's settled state to a
  numbered PNG. Desktop asks for a folder; the web downloads the files.
- **Export PDF** renders the same settled states into one PDF, a page per
  slide at the deck's canvas size. Desktop asks where to save the file;
  the web downloads it.
- **Export video (MP4)** renders the deck through fluvie's real pipeline.
  The desktop renders through your local FFmpeg into a file you pick. The
  web renders fully in the browser through ffmpeg.wasm and lands as a
  download; the page must ship the `FluvieFfmpeg` bridge in `index.html`.
  Without the bridge the entry stays visible but disabled and names what
  is missing. See [Video mode](editor-video-mode.md) for the details.

## Web and desktop

| Capability | Desktop | Web |
| --- | --- | --- |
| Edit, present, save, autosave | yes | yes |
| Export .fluvie and Dart source | yes | yes (File System Access or download) |
| Export slide images | yes, into a folder | yes, as downloads |
| Export PDF | yes, into a picked file | yes, as a download |
| Export video (MP4) | yes, local FFmpeg | yes, ffmpeg.wasm (the page ships the FluvieFfmpeg bridge) |

## Where to next

- [The canvas](editor-canvas.md): tools, selection, snapping, groups, and
  the command palette.
- [The timeline](editor-timeline.md): animation bars, keyframes, build
  steps, and the playhead.
- [Continuity across slides](editor-continuity.md): overlays, shared chains,
  and the difference between a hairline and a bar edge.
- [Themes, masters, and templates](editor-themes.md): restyle a whole deck
  from one palette.
- [Shortcuts](editor-shortcuts.md): the full key map.
- [The start screen](editor-start-screen.md): recents, templates, and where
  the samples live.
- [FAQ](editor-faq.md): short answers to the questions the editor raises.
