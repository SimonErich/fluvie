# Fluvie example app

The Fluvie example app is the lesson gallery and inspector. Run it from the
repository root so its render button can find the Fluvie CLI:

```sh
flutter run
```

## The three panes

- Lesson list (left): every lesson in registry order. Tap one to select it
  everywhere.
- Scrubber and render (center): the live preview with a frame slider, plus a
  "Render MP4" button that runs the selected lesson through the CLI.
- Inspector (right): the structured timeline for the selected lesson, every
  animation, its owner, and its absolute frame span.

## The render button

The render button shells out to the Fluvie CLI, which renders the lesson with
FFmpeg. Run the app from the repository root so the CLI can find the capture
harness and the toolchain. Output lands under `build/<lesson>.mp4`, and the
combined CLI output shows beneath the button.
