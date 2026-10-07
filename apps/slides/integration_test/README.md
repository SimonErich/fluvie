# Slides end-to-end tests

These tests drive the real editor app end to end on the Linux desktop
embedder. They mount the actual `SlidesApp` (or its real `EditorScreen`),
tap real controls, and assert real outcomes. Every seam is faked, so the run
is deterministic: no file IO, no network, no OS dialogs.

## Run them

You need a display (`DISPLAY` set; there is no headless fallback baked in):

```sh
flutter test integration_test -d linux
```

Or through Melos from the repo root:

```sh
melos run test:e2e
```

The tests are tagged `e2e`, so the default `melos run gate` never runs them.
A window flashes open while the suite runs; that is expected on a real embedder.

The journeys live in one file, `editor_e2e_test.dart`. That is deliberate:
`flutter test <dir> -d linux` relaunches the desktop app once per file and only
the first launch attaches a debug connection reliably here, so a multi-file
suite would fail to start its later files. Sibling `testWidgets` under one
launch sidestep that.

## What each journey covers

- Authoring — new blank deck, place and style a headline, add and duplicate
  slides, present, and return with the deck intact.
- Video geometry — video mode parks a later scene on its settled frame, the
  render sits where the editor geometry places it, and a drag commits a sane
  on-canvas placement (the "X = -52.3" regression guard).
- Assets import — the assets panel imports a new file into the reusable media
  store beside an existing entry.
- Theme switch — applying a builtin theme restyles the document.
- Export — Export PDF writes one page per slide and Export slide images writes
  one PNG per slide.

## Where to next

- The widget-journey tests under `../test` for the same features at unit speed.
