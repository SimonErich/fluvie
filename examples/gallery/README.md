# Fluvie example app

The Fluvie example app is the lesson gallery and inspector. Run it from its
directory in a clone of the repository; its render button shells out to the
Fluvie CLI, which it finds by walking up to the repository root:

```sh
cd examples/gallery
flutter run
```

> The gallery is a **registry-based project**: it keeps a composition registry and
> a committed capture harness so thirteen lessons can live side by side under one
> app, and it renders by key. That is not the shape of a project you write. Yours
> is a composition file, an `assets/` folder, and a pubspec, previewed with
> `fluvie preview ./lib/my_video.dart` and rendered with `fluvie render ./lib/my_video.dart`.
> See [Start a project](../../documentation/getting-started/start-a-project.md).

## The three panes

- Lesson list (left): every lesson in registry order. Tap one to select it
  everywhere.
- Scrubber and render (center): the live preview with a frame slider, plus a
  "Render MP4" button that runs the selected lesson through the CLI.
- Inspector (right): the structured timeline for the selected lesson, every
  animation, its owner, and its absolute frame span.

## The render button

The render button shells out to the Fluvie CLI, which renders the lesson with
FFmpeg. The CLI finds the project by walking up from the app directory until it
hits a pubspec that depends on `fluvie`, so run the app from a clone of the
repository. Because the gallery keeps a registry, the render goes by key and uses
the committed harness. Output lands under `build/<lesson>.mp4`, and the combined
CLI output shows beneath the button.
