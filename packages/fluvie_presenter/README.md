# fluvie_presenter

Present a [Fluvie](https://github.com/SimonErich/fluvie) `Video` live. Same
scenes, same timing engine, but instead of rendering a video file, the
presenter plays your scenes as slides, driven by a real clock and stepped by
input like Keynote or reveal.js.

[![CI](https://github.com/SimonErich/fluvie/actions/workflows/ci.yaml/badge.svg)](https://github.com/SimonErich/fluvie/actions/workflows/ci.yaml)
[![coverage](https://codecov.io/gh/SimonErich/fluvie/branch/main/graph/badge.svg)](https://codecov.io/gh/SimonErich/fluvie)
[![license: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

```dart
import 'package:fluvie_presenter/fluvie_presenter.dart';

void main() => runApp(FluvieSlides(video));
```

That is the whole integration. The same `Video` still renders to a file.

## Features

- **Scenes are slides.** No second authoring format; the deck is your video.
- **Builds with `Stop`.** Wrap content to reveal it click by click. Entrances
  play forward; backs and jumps land on settled states, instantly.
- **Ambient motion never pauses.** A slide holds while loops keep looping.
- **Speaker notes.** `SpeakerNotes` per scene or per step, shown in a
  togglable panel and in the speaker window, never on the stage.
- **Slide sidebar and overview grid** rendered from one lazy, capped preview
  cache. Click any slide to jump.
- **Speaker window.** Current slide, next state, notes, elapsed clock; a
  synced popup on the web, a pluggable launcher seam on desktop.
- **Presenter chrome.** Fullscreen, black/white screen covers, digit-jump,
  and the full keyboard/remote/touch input map.
- **A public engine surface.** `PresentationController`, `compileSlidePlans`,
  and `compileNotes` for building your own chrome.

## Install

`fluvie_presenter` lives in the Fluvie monorepo and is not on pub.dev yet
(its UI chrome pins a git dependency). Depend on it from git:

```yaml
dependencies:
  fluvie: ^0.2.0
  fluvie_presenter:
    git:
      url: https://github.com/SimonErich/fluvie.git
      path: packages/fluvie_presenter
```

Inside the monorepo, a path dependency and `melos bootstrap` do the same.

## Learn more

- Start with the docs in
  [`documentation/`](https://github.com/SimonErich/fluvie/tree/main/packages/fluvie_presenter/documentation):
  getting started, guides, advanced, and the shortcut reference.
- Run the deployable shell in
  [`apps/slides`](https://github.com/SimonErich/fluvie/tree/main/apps/slides)
  and click through the bundled tutorial decks, or open your own `.fluvie`
  file.
- Changes are tracked in the
  [CHANGELOG](https://github.com/SimonErich/fluvie/blob/main/packages/fluvie_presenter/CHANGELOG.md).
