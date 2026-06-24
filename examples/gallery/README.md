# Fluvie example app

The Fluvie example app is the lesson gallery and inspector. Run it from its
directory in a clone of the repository; its render button shells out to the
Fluvie CLI, which it finds by walking up to the repository root:

```sh
cd examples/gallery
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
FFmpeg. The CLI finds the capture harness and toolchain by walking up from the
app directory, so run the app from a clone of the repository. Output lands under
`build/<lesson>.mp4`, and the combined CLI output shows beneath the button.
